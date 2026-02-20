import Foundation
import SwiftData

enum WorkoutSessionFactory {
    struct SetTemplate: Hashable {
        var order: Int
        var targetReps: Int?
        var targetWeight: Double?
        var targetWeightUnit: WeightUnit
        var targetRPE: Double?
        var targetRestSeconds: Int?
    var targetDurationSeconds: Int? = nil
        var targetDistance: Double? = nil
    }

    struct ExerciseTemplate: Hashable {
        var order: Int
        var exerciseId: UUID
        var nameSnapshot: String
        var notes: String?
        var sets: [SetTemplate]
    }

    static func makeSession(
        startedAt: Date = Date(),
        linkedActivityId: UUID?,
        sourceRoutineId: UUID?,
        sourceRoutineNameSnapshot: String?,
        exercises: [ExerciseTemplate],
        prefillActualsFromTargets: Bool = true
    ) -> WorkoutSession {
        let session = WorkoutSession(
            startedAt: startedAt,
            sourceRoutineId: sourceRoutineId,
            sourceRoutineNameSnapshot: sourceRoutineNameSnapshot,
            linkedActivityId: linkedActivityId
        )

        let sortedExercises = exercises.sorted { $0.order < $1.order }

        session.exercises = sortedExercises.map { ex in
            let se = WorkoutSessionExercise(
                order: ex.order,
                exerciseId: ex.exerciseId,
                exerciseNameSnapshot: ex.nameSnapshot,
                notes: ex.notes,
                session: session
            )

            let sortedSets = ex.sets.sorted { $0.order < $1.order }

            se.setLogs = sortedSets.map { st in
                let log = WorkoutSetLog(
                    order: st.order,
                    origin: .planned,
                    reps: prefillActualsFromTargets ? st.targetReps : nil,
                    weight: prefillActualsFromTargets ? st.targetWeight : nil,
                    weightUnit: st.targetWeightUnit,
                    rpe: prefillActualsFromTargets ? st.targetRPE : nil,
                    completed: false,
                    targetReps: st.targetReps,
                    targetWeight: st.targetWeight,
                    targetWeightUnit: st.targetWeightUnit,
                    targetRPE: st.targetRPE,
                    targetRestSeconds: st.targetRestSeconds,
                    sessionExercise: se
                )

                // Timed / distance targets (used for cardio, intervals, mobility, etc.)
                log.targetDurationSeconds = st.targetDurationSeconds
                log.targetDistance = st.targetDistance

                if prefillActualsFromTargets {
                    log.actualDurationSeconds = st.targetDurationSeconds
                    log.actualDistance = st.targetDistance
                }

                return log
            }

            return se
        }

        return session
    }
}
