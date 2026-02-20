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
                    sets: sets
                )
            )
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
