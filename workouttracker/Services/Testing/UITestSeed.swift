import Foundation
import SwiftData

enum UITestSeed {

    @MainActor
    static func ensureInProgressSession(context: ModelContext) throws -> WorkoutSession {

        // Reuse existing in-progress session if present (stabilizes relaunches)
        let fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
        if let existing = try context.fetch(fd).first(where: { $0.status == .inProgress }) {
            return existing
        }

        // Create minimal session (DON'T pass status/endedAt unless your init supports them)
        let session = WorkoutSession(
            startedAt: Date(),
            sourceRoutineNameSnapshot: "UI Test Session"
        )
        session.status = .inProgress
        session.endedAt = nil   // only keep this line IF endedAt exists as a property on the model

        let ex = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Bench Press",
            session: session
        )

        let s1 = WorkoutSetLog(
            order: 0,
            origin: .planned,
            reps: nil,
            weight: nil,
            weightUnit: .kg,
            rpe: nil,
            completed: false,
            targetReps: 10,
            targetWeight: 100,
            targetWeightUnit: .kg,
            targetRPE: nil,
            targetRestSeconds: 90,
            sessionExercise: ex
        )

        let s2 = WorkoutSetLog(
            order: 1,
            origin: .planned,
            reps: nil,
            weight: nil,
            weightUnit: .kg,
            rpe: nil,
            completed: false,
            targetReps: 10,
            targetWeight: 100,
            targetWeightUnit: .kg,
            targetRPE: nil,
            targetRestSeconds: 90,
            sessionExercise: ex
        )

        ex.setLogs = [s1, s2]
        session.exercises = [ex]

        context.insert(session)
        try context.save()
        return session
    }
}
