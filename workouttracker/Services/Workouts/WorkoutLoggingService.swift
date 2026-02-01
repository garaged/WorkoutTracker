import Foundation
import SwiftData
import Combine

/// Centralizes workout set logging mutations (add/copy/delete/toggle complete) and provides
/// a simple "undo last action" stack for the current session.
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
    private let toastDurationSeconds: Double

    init(now: @escaping () -> Date = Date.init) {
        self.now = now

        // ✅ In UI tests, keep the toast around longer to avoid timing flake.
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            self.toastDurationSeconds = 8.0
        } else {
            self.toastDurationSeconds = 2.5
        }
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

        // ✅ Always work off a stable ordering first.
        Self.normalizeSetLogArrayOrder(in: ex)

        // Build a new set (order will be corrected by renumber).
        let newSet = Self.makeSet(for: ex, template: template)

        // Compute insertion index AFTER normalization, and compare by id (SwiftData-safe).
        let insertIndex = Self.insertionIndex(in: ex, after: after)

        // Insert and then renumber preserving the current array order.
        ex.setLogs.insert(newSet, at: min(insertIndex, ex.setLogs.count))
        Self.renumberOrdersPreservingArray(in: ex)

        pushUndo(message: "Added set") { ctx in
            if let idx = ex.setLogs.firstIndex(where: { $0.id == newSet.id }) {
                ex.setLogs.remove(at: idx)
                ctx.delete(newSet)
                Self.renumberOrdersPreservingArray(in: ex)
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

        Self.normalizeSetLogArrayOrder(in: ex)

        let copied = Self.makeSetCopy(source, for: ex)

        let insertIndex = Self.insertionIndex(in: ex, after: source)
        ex.setLogs.insert(copied, at: min(insertIndex, ex.setLogs.count))
        Self.renumberOrdersPreservingArray(in: ex)

        pushUndo(message: "Copied set") { ctx in
            if let idx = ex.setLogs.firstIndex(where: { $0.id == copied.id }) {
                ex.setLogs.remove(at: idx)
                ctx.delete(copied)
                Self.renumberOrdersPreservingArray(in: ex)
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
        Self.normalizeSetLogArrayOrder(in: ex)

        guard let idx = ex.setLogs.firstIndex(where: { $0.id == set.id }) else { return }

        // ✅ Snapshot everything needed to restore faithfully (including identity).
        let originalID = set.id
        let originalOrigin = set.origin

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
        Self.renumberOrdersPreservingArray(in: ex)

        pushUndo(message: "Deleted set") { ctx in
            let restored = WorkoutSetLog(
                id: originalID,                    // ✅ restore same identity
                order: insertIndex,
                origin: originalOrigin,            // ✅ restore origin
                reps: reps,
                weight: weight,
                weightUnit: weightUnit,
                rpe: rpe,
                completed: completed,
                completedAt: completedAt,
                targetReps: targetReps,
                targetWeight: targetWeight,
                targetWeightUnit: targetWeightUnit,
                targetRPE: targetRPE,
                targetRestSeconds: targetRestSeconds,
                sessionExercise: ex
            )

            // Being explicit makes undo behavior more predictable across SwiftData versions.
            ctx.insert(restored)

            ex.setLogs.insert(restored, at: min(insertIndex, ex.setLogs.count))
            Self.renumberOrdersPreservingArray(in: ex)
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

    /// Quick stepper: weight +/- (clamped at 0).
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

        dismissTask?.cancel()
        dismissTask = nil

        // Capture the duration outside the Task closure to satisfy Swift 6 explicit-capture rules.
        // This avoids referencing `self` (captured weakly) before the `guard let self`.
        let delaySeconds = toastDurationSeconds

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard let self else { return }
if self.undoToast?.id == toast.id {
                self.undoToast = nil
            }
        }
    }

    // MARK: - Helpers

    private static func insertionIndex(in ex: WorkoutSessionExercise, after: WorkoutSetLog?) -> Int {
        guard let after else { return ex.setLogs.count }
        guard let idx = ex.setLogs.firstIndex(where: { $0.id == after.id }) else { return ex.setLogs.count }
        return min(idx + 1, ex.setLogs.count)
    }

    /// Sorts current setLogs by their persisted order so we have a stable base for insertion.
    private static func normalizeSetLogArrayOrder(in ex: WorkoutSessionExercise) {
        ex.setLogs.sort { $0.order < $1.order }
    }

    /// Renumbers orders based on the CURRENT array order. (No sorting here.)
    private static func renumberOrdersPreservingArray(in ex: WorkoutSessionExercise) {
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
