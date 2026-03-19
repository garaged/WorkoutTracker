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
        var trackingStyle: ExerciseTrackingStyle
        var segment: WorkoutExerciseSegment = .main
        var sets: [SetTemplate]
        var segmentKind: SessionSegmentKind = .main
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

        // Stable sort and then normalize to session-wide sequential order.
        let normalizedExercises: [ExerciseTemplate] = exercises
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.order != rhs.element.order {
                    return lhs.element.order < rhs.element.order
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        session.exercises = normalizedExercises.enumerated().map { exerciseIndex, ex in
            let se = WorkoutSessionExercise(
                order: exerciseIndex,
                exerciseId: ex.exerciseId,
                exerciseNameSnapshot: ex.nameSnapshot,
                notes: ex.notes,
                trackingStyle: ex.trackingStyle,
                segment: ex.segment,
                session: session
            )

            let normalizedSets: [SetTemplate] = ex.sets
                .enumerated()
                .sorted { lhs, rhs in
                    if lhs.element.order != rhs.element.order {
                        return lhs.element.order < rhs.element.order
                    }
                    return lhs.offset < rhs.offset
                }
                .map(\.element)

            se.setLogs = normalizedSets.enumerated().map { setIndex, st in
                let log = WorkoutSetLog(
                    order: setIndex,
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
