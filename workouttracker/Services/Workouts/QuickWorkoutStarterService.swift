import Foundation
import SwiftData

@MainActor
final class QuickWorkoutStarterService {

    static let quickWorkoutName = "Quick Workout"

    private let reuseWindow: TimeInterval = 4 * 60 * 60

    func startOrReuseQuickSession(
        exerciseId: UUID,
        exerciseNameSnapshot: String,
        context: ModelContext
    ) throws -> WorkoutSession {

        let now = Date()

        if let existing = try fetchEligibleInProgressQuickSession(now: now, context: context) {
            try prepareSessionForTarget(
                session: existing,
                exerciseId: exerciseId,
                exerciseNameSnapshot: exerciseNameSnapshot,
                context: context
            )
            return existing
        }

        let session = WorkoutSession(startedAt: now)
        session.sourceRoutineNameSnapshot = Self.quickWorkoutName
        session.status = .inProgress
        session.endedAt = nil

        context.insert(session)

        try prepareSessionForTarget(
            session: session,
            exerciseId: exerciseId,
            exerciseNameSnapshot: exerciseNameSnapshot,
            context: context
        )

        return session
    }

    /// Use this when the user chooses "Resume current workout":
    /// it adds the exercise to that session (if missing) and guarantees at least one incomplete set exists.
    func prepareSessionForTarget(
        session: WorkoutSession,
        exerciseId: UUID,
        exerciseNameSnapshot: String,
        context: ModelContext
    ) throws {
        let ex = try ensureExercise(
            exerciseId: exerciseId,
            name: exerciseNameSnapshot,
            in: session,
            context: context
        )

        try ensureIncompleteSetExists(for: ex, context: context)

        try? context.save()
    }

    // MARK: - Reuse rules

    private func fetchEligibleInProgressQuickSession(now: Date, context: ModelContext) throws -> WorkoutSession? {
        var fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
        fd.fetchLimit = 10

        let candidates = try context.fetch(fd).filter { $0.status == .inProgress }

        // ✅ Only reuse in-progress "Quick Workout" sessions (never routine sessions)
        return candidates.first(where: { s in
            s.sourceRoutineNameSnapshot == Self.quickWorkoutName &&
            now.timeIntervalSince(s.startedAt) < reuseWindow
        })
    }

    // MARK: - Internals

    private func ensureExercise(
        exerciseId: UUID,
        name: String,
        in session: WorkoutSession,
        context: ModelContext
    ) throws -> WorkoutSessionExercise {

        if let existing = session.exercises.first(where: { $0.exerciseId == exerciseId }) {
            return existing
        }

        let ex = WorkoutSessionExercise(
            order: session.exercises.count,
            exerciseId: exerciseId,
            exerciseNameSnapshot: name,
            notes: nil,
            session: session
        )

        context.insert(ex)
        session.exercises.append(ex)
        return ex
    }

    private func ensureIncompleteSetExists(for ex: WorkoutSessionExercise, context: ModelContext) throws {
        if ex.setLogs.contains(where: { !$0.completed }) {
            return
        }

        let nextOrder = (ex.setLogs.map(\.order).max() ?? -1) + 1

        let log = WorkoutSetLog(
            order: nextOrder,
            reps: nil,
            weight: nil,
            weightUnit: .kg,
            completed: false,
            completedAt: nil,
            targetReps: nil,
            targetWeight: nil,
            targetWeightUnit: .kg,
            targetRPE: nil,
            targetRestSeconds: nil,
            sessionExercise: ex
        )

        context.insert(log)
        ex.setLogs.append(log)
    }
}
