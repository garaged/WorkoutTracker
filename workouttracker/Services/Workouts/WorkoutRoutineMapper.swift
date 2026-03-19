import Foundation

enum WorkoutRoutineMapper {
    struct ExecutionSegment: Hashable {
        let kind: WorkoutExerciseSegment
        let routineID: UUID
        let routineName: String
        let exerciseItems: [WorkoutRoutineItem]
    }

    static func toExecutionSegments(routine: WorkoutRoutine) -> [ExecutionSegment] {
        var segments: [ExecutionSegment] = []

        if let warmUpRoutine = routine.warmUpRoutine {
            let items = warmUpRoutine.items.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            if !items.isEmpty {
                segments.append(
                    ExecutionSegment(
                        kind: .warmUp,
                        routineID: warmUpRoutine.id,
                        routineName: warmUpRoutine.name,
                        exerciseItems: items
                    )
                )
            }
        }

        let mainItems = routine.items.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        if !mainItems.isEmpty {
            segments.append(
                ExecutionSegment(
                    kind: .main,
                    routineID: routine.id,
                    routineName: routine.name,
                    exerciseItems: mainItems
                )
            )
        }

        if let coolDownRoutine = routine.coolDownRoutine {
            let items = coolDownRoutine.items.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            if !items.isEmpty {
                segments.append(
                    ExecutionSegment(
                        kind: .coolDown,
                        routineID: coolDownRoutine.id,
                        routineName: coolDownRoutine.name,
                        exerciseItems: items
                    )
                )
            }
        }

        return segments
    }

    static func toExerciseTemplates(routine: WorkoutRoutine) -> [WorkoutSessionFactory.ExerciseTemplate] {
        toExerciseTemplates(executionSegments: toExecutionSegments(routine: routine))
    }

    static func toExerciseTemplates(executionSegments: [ExecutionSegment]) -> [WorkoutSessionFactory.ExerciseTemplate] {
        var out: [WorkoutSessionFactory.ExerciseTemplate] = []
        out.reserveCapacity(executionSegments.reduce(0) { $0 + $1.exerciseItems.count })

        var flattenedOrder = 0

        for executionSegment in executionSegments {
            for item in executionSegment.exerciseItems {
                guard let ex = item.exercise else { continue }

                let plans = item.setPlans.sorted { lhs, rhs in
                    if lhs.order != rhs.order { return lhs.order < rhs.order }
                    return lhs.id.uuidString < rhs.id.uuidString
                }

                let sets: [WorkoutSessionFactory.SetTemplate] =
                    plans.isEmpty
                    ? [defaultSet(order: 0, style: item.trackingStyle)]
                    : plans.map { p in
                        WorkoutSessionFactory.SetTemplate(
                            order: p.order,
                            targetReps: p.targetReps,
                            targetWeight: p.targetWeight,
                            targetWeightUnit: p.weightUnit,
                            targetRPE: p.targetRPE,
                            targetRestSeconds: p.restSeconds,
                            targetDurationSeconds: p.targetDurationSeconds,
                            targetDistance: p.targetDistance
                        )
                    }

                let resolvedSegment: WorkoutExerciseSegment
                switch executionSegment.kind {
                case .warmUp, .coolDown:
                    // Linked warm-up/cool-down routines should always project their execution role,
                    // even if their routine items were created with the default `.main` segment.
                    resolvedSegment = executionSegment.kind
                case .main:
                    // Main routine items may intentionally carry a custom segment on standalone flows.
                    resolvedSegment = item.segment
                }

                out.append(
                    WorkoutSessionFactory.ExerciseTemplate(
                        order: flattenedOrder,
                        exerciseId: ex.id,
                        nameSnapshot: ex.name,
                        notes: item.notes,
                        trackingStyle: item.trackingStyle,
                        segment: resolvedSegment,
                        sets: sets
                    )
                )

                flattenedOrder += 1
            }
        }

        return out
    }

    private static func defaultSet(order: Int, style: ExerciseTrackingStyle) -> WorkoutSessionFactory.SetTemplate {
        var t = WorkoutSessionFactory.SetTemplate(
            order: order,
            targetReps: nil,
            targetWeight: nil,
            targetWeightUnit: .kg,
            targetRPE: nil,
            targetRestSeconds: nil,
            targetDurationSeconds: nil,
            targetDistance: nil
        )

        if style.showsReps { t.targetReps = 10 }
        if style.showsWeight { t.targetRestSeconds = 90 }

        if style.showsDuration {
            t.targetDurationSeconds = 10 * 60
        }

        if style.showsDistance {
            if t.targetDurationSeconds == nil { t.targetDurationSeconds = 20 * 60 }
            t.targetDistance = 3.0
        }

        return t
    }
}
