import Foundation

enum WorkoutRoutineMapper {
    static func toExerciseTemplates(routine: WorkoutRoutine) -> [WorkoutSessionFactory.ExerciseTemplate] {
        let items = routine.items.sorted { $0.order < $1.order }

        var out: [WorkoutSessionFactory.ExerciseTemplate] = []
        out.reserveCapacity(items.count)

        for item in items {
            guard let ex = item.exercise else { continue }

            let plans = item.setPlans.sorted { $0.order < $1.order }
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

            out.append(
                WorkoutSessionFactory.ExerciseTemplate(
                    order: item.order,
                    exerciseId: ex.id,
                    nameSnapshot: ex.name,
                    notes: item.notes,
                    trackingStyle: item.trackingStyle,
                    segment: item.segment,
                    sets: sets
                )
            )
        }

        return out
    }

    static func toExecutionSegments(routine: WorkoutRoutine) -> [RoutineExecutionSegment] {
        RoutineLinkPlanner.buildExecutionSegments(for: routine)
    }

    static func toExerciseTemplates(executionSegments: [RoutineExecutionSegment]) -> [WorkoutSessionFactory.ExerciseTemplate] {
        var out: [WorkoutSessionFactory.ExerciseTemplate] = []
        var nextOrder = 0

        for segment in executionSegments {
            let items = segment.exerciseItems.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            for item in items {
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

                out.append(
                    WorkoutSessionFactory.ExerciseTemplate(
                        order: nextOrder,
                        exerciseId: ex.id,
                        nameSnapshot: ex.name,
                        notes: item.notes,
                        trackingStyle: item.trackingStyle,
                        sets: sets,
                        segmentKind: segment.kind
                    )
                )
                nextOrder += 1
            }
        }

        return out
    }

    private static func defaultSet(order: Int, style: ExerciseTrackingStyle) -> WorkoutSessionFactory.SetTemplate {
        // Use the same "capability" flags the routine editor UI uses, so this stays future-proof
        // if you add new styles later.
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
            // Default: 10 minutes
            t.targetDurationSeconds = 10 * 60
        }

        if style.showsDistance {
            // If distance is tracked, also default a duration if none was set.
            if t.targetDurationSeconds == nil { t.targetDurationSeconds = 20 * 60 }
            t.targetDistance = 3.0
        }

        return t
    }
}
