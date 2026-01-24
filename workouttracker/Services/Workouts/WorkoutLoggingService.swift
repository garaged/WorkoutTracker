import Foundation
import SwiftData
import Combine

/// Centralizes workout set logging mutations (add/copy/delete/toggle complete) and provides
/// a simple "undo last action" stack for the current session.
///
/// Why this exists:
/// - SwiftUI rows should stay dumb UI: they request actions; they don't reinvent mutation rules.
/// - Mutations like "insert + renumber orders" and "toggle done + timestamp" are easy to get subtly wrong.
/// - Undo is easiest when the service records an inverse operation at the time of the change.
///
/// Notes:
/// - Undo history is session-local (in-memory). If the app is killed, undo history is lost.
/// - TextField edits in the row still edit the model directly; this service focuses on fast tap actions
///   (copy, +1 set, steppers, done).
@MainActor
final class WorkoutLoggingService: ObservableObject {

    struct UndoToast: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    /// When non-nil, the UI can show an undo toast.
    @Published private(set) var undoToast: UndoToast? = nil

    private struct UndoStep {
        let message: String
        let undo: (ModelContext) throws -> Void
    }

    private var undoStack: [UndoStep] = []
    private var dismissTask: Task<Void, Never>?

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    deinit { dismissTask?.cancel() }

    // MARK: - Public API

    /// Adds a new set after `after` if provided, otherwise appends at the end.
    /// The new set is prefilled from `template` (usually the last set) for speed.
    @discardableResult
    func addSet(
        to ex: WorkoutSessionExercise,
        after: WorkoutSetLog? = nil,
        template: WorkoutSetLog? = nil,
        context: ModelContext
    ) -> WorkoutSetLog? {
        let newSet = Self.makeSet(for: ex, template: template)

        let insertIndex = Self.insertionIndex(in: ex, after: after)
        ex.setLogs.insert(newSet, at: insertIndex)
        Self.renumberOrders(in: ex)

        pushUndo(message: "Added set") { ctx in
            if let idx = ex.setLogs.firstIndex(where: { $0 === newSet }) {
                ex.setLogs.remove(at: idx)
                ctx.delete(newSet)
                Self.renumberOrders(in: ex)
                try ctx.save()
            }
        }

        save(context, label: "add set")
        return newSet
    }

    /// Copies `source` into a new set and inserts it right after `source` (or at the end if not found).
    @discardableResult
    func copySet(
        _ source: WorkoutSetLog,
        in ex: WorkoutSessionExercise,
        context: ModelContext
    ) -> WorkoutSetLog? {
        let copied = Self.makeSetCopy(source, for: ex)

        let insertIndex = Self.insertionIndex(in: ex, after: source)
        ex.setLogs.insert(copied, at: insertIndex)
        Self.renumberOrders(in: ex)

        pushUndo(message: "Copied set") { ctx in
            if let idx = ex.setLogs.firstIndex(where: { $0 === copied }) {
                ex.setLogs.remove(at: idx)
                ctx.delete(copied)
                Self.renumberOrders(in: ex)
                try ctx.save()
            }
        }

        save(context, label: "copy set")
        return copied
    }

    func deleteSet(
        _ set: WorkoutSetLog,
        from ex: WorkoutSessionExercise,
        context: ModelContext
    ) {
        guard let idx = ex.setLogs.firstIndex(where: { $0 === set }) else { return }

        // Snapshot fields needed to rebuild (types are inferred from the model).
        let reps = set.reps
        let weight = set.weight
        let weightUnit = set.weightUnit
        let rpe = set.rpe
        let completed = set.completed
        let completedAt = set.completedAt

        let targetReps = set.targetReps
        let targetWeight = set.targetWeight
        let targetWeightUnit = set.targetWeightUnit
        let targetRPE = set.targetRPE
        let targetRestSeconds = set.targetRestSeconds

        let insertIndex = idx

        ex.setLogs.remove(at: idx)
        context.delete(set)
        Self.renumberOrders(in: ex)

        pushUndo(message: "Deleted set") { ctx in
            let restored = WorkoutSetLog(
                order: insertIndex,
                origin: .added,
                reps: reps,
                weight: weight,
                weightUnit: weightUnit,
                rpe: rpe,
                completed: completed,
                targetReps: targetReps,
                targetWeight: targetWeight,
                targetWeightUnit: targetWeightUnit,
                targetRPE: targetRPE,
                targetRestSeconds: targetRestSeconds,
                sessionExercise: ex
            )
            restored.completedAt = completedAt

            ex.setLogs.insert(restored, at: min(insertIndex, ex.setLogs.count))
            Self.renumberOrders(in: ex)
            try ctx.save()
        }

        save(context, label: "delete set")
    }

    /// Toggle done state with timestamping + undo.
    func toggleCompleted(
        _ set: WorkoutSetLog,
        context: ModelContext
    ) {
        let oldCompleted = set.completed
        let oldCompletedAt = set.completedAt

        set.completed.toggle()
        set.completedAt = set.completed ? now() : nil

        pushUndo(message: set.completed ? "Marked done" : "Marked not done") { ctx in
            set.completed = oldCompleted
            set.completedAt = oldCompletedAt
            try ctx.save()
        }

        save(context, label: "toggle completed")
    }

    /// Quick stepper: reps +/-.
    func bumpReps(
        _ set: WorkoutSetLog,
        delta: Int,
        context: ModelContext
    ) {
        guard delta != 0 else { return }

        let oldReps = set.reps

        let current = set.reps ?? 0
        set.reps = max(0, current + delta)

        pushUndo(message: "Adjusted reps") { ctx in
            set.reps = oldReps
            try ctx.save()
        }

        save(context, label: "bump reps")
    }

    /// Quick stepper: weight +/- (clamped at 0). Uses current unit; the UI decides the step size.
    func bumpWeight(
        _ set: WorkoutSetLog,
        delta: Double,
        context: ModelContext
    ) {
        guard delta != 0 else { return }

        let oldWeight = set.weight

        let current = set.weight ?? 0
        let next = max(0, current + delta)
        set.weight = next == 0 ? nil : next

        pushUndo(message: "Adjusted weight") { ctx in
            set.weight = oldWeight
            try ctx.save()
        }

        save(context, label: "bump weight")
    }

    func undoLast(context: ModelContext) {
        guard let step = undoStack.popLast() else { return }
        do {
            try step.undo(context)
        } catch {
            assertionFailure("Undo failed: \(error)")
        }

        if undoStack.isEmpty {
            undoToast = nil
        } else {
            showToast(message: undoStack.last!.message)
        }
    }

    func clearUndoToast() {
        undoToast = nil
        dismissTask?.cancel()
        dismissTask = nil
    }

    // MARK: - Internals

    private func save(_ context: ModelContext, label: String) {
        do { try context.save() }
        catch { assertionFailure("Failed to save (\(label)): \(error)") }
    }

    private func pushUndo(message: String, undo: @escaping (ModelContext) throws -> Void) {
        undoStack.append(.init(message: message, undo: undo))
        showToast(message: message)
    }

    private func showToast(message: String) {
        let toast = UndoToast(message: message)
        undoToast = toast

        // Auto-dismiss after a short delay (but keep undo stack).
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self else { return }
            if self.undoToast?.id == toast.id {
                self.undoToast = nil
            }
        }
    }

    // MARK: - Helpers

    private static func insertionIndex(in ex: WorkoutSessionExercise, after: WorkoutSetLog?) -> Int {
        guard let after else { return ex.setLogs.count }
        guard let idx = ex.setLogs.firstIndex(where: { $0 === after }) else { return ex.setLogs.count }
        return min(idx + 1, ex.setLogs.count)
    }

    private static func renumberOrders(in ex: WorkoutSessionExercise) {
        for (i, s) in ex.setLogs.enumerated() {
            s.order = i
        }
    }

    private static func makeSet(for ex: WorkoutSessionExercise, template: WorkoutSetLog?) -> WorkoutSetLog {
        let t = template ?? ex.setLogs.last

        return WorkoutSetLog(
            order: ex.setLogs.count,
            origin: .added,
            reps: t?.reps ?? t?.targetReps,
            weight: t?.weight ?? t?.targetWeight,
            weightUnit: t?.weightUnit ?? (t?.targetWeightUnit ?? .kg),
            rpe: t?.rpe ?? t?.targetRPE,
            completed: false,
            targetReps: t?.targetReps,
            targetWeight: t?.targetWeight,
            targetWeightUnit: t?.targetWeightUnit ?? .kg,
            targetRPE: t?.targetRPE,
            targetRestSeconds: t?.targetRestSeconds,
            sessionExercise: ex
        )
    }

    private static func makeSetCopy(_ source: WorkoutSetLog, for ex: WorkoutSessionExercise) -> WorkoutSetLog {
        WorkoutSetLog(
            order: ex.setLogs.count,
            origin: .added,
            reps: source.reps,
            weight: source.weight,
            weightUnit: source.weightUnit,
            rpe: source.rpe,
            completed: false,
            targetReps: source.targetReps,
            targetWeight: source.targetWeight,
            targetWeightUnit: source.targetWeightUnit,
            targetRPE: source.targetRPE,
            targetRestSeconds: source.targetRestSeconds,
            sessionExercise: ex
        )
    }
}
