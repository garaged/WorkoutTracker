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
                ? [defaultSet(order: 0)]
                : plans.map { p in
                    WorkoutSessionFactory.SetTemplate(
                        order: p.order,
                        targetReps: p.targetReps,
                        targetWeight: p.targetWeight,
                        targetWeightUnit: p.weightUnit,
                        targetRPE: p.targetRPE,
                        targetRestSeconds: p.restSeconds
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

    private static func defaultSet(order: Int) -> WorkoutSessionFactory.SetTemplate {
        .init(order: order, targetReps: 10, targetWeight: nil, targetWeightUnit: .kg, targetRPE: nil, targetRestSeconds: 90)
    }
}
