import Foundation
import SwiftData

@MainActor
enum AppSeeder {
    // Bump when you change the bundled seed JSONs.
    private static let seedVersion = 1
    private static let seedKey = "workouttracker.seedVersion"

    static func seedIfNeeded(context: ModelContext) {
        let current = UserDefaults.standard.integer(forKey: seedKey)
        guard current < seedVersion else { return }

        // Only seed when user is effectively "fresh".
        // This avoids surprising experienced users.
        let existingExerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let existingRoutineCount  = (try? context.fetchCount(FetchDescriptor<WorkoutRoutine>())) ?? 0

        guard existingExerciseCount == 0 && existingRoutineCount == 0 else {
            UserDefaults.standard.set(seedVersion, forKey: seedKey)
            return
        }

        do {
            let catalog = try SeedCatalog.loadFromBundle()

            // 1) Exercises
            var exerciseByKey: [String: Exercise] = [:]
            for ex in catalog.exercises {
                let e = Exercise(
                    id: ex.id,
                    name: ex.name,
                    // Adapt these to your model fields:
                    // modality: ex.modality,
                    // muscleGroups: ex.muscleGroups,
                    // equipment: ex.equipment
                    // notes: ex.notes
                    notes: ex.notes
                )
                context.insert(e)
                exerciseByKey[ex.key] = e
            }

            // 2) Routines + items + plans
            for r in catalog.routines {
                let routine = WorkoutRoutine(id: r.id, name: r.name)
                context.insert(routine)

                for (idx, item) in r.items.enumerated() {
                    guard let ex = exerciseByKey[item.exerciseKey] else { continue }

                    let ri = WorkoutRoutineItem(
                        order: idx,
                        routine: routine,
                        exercise: ex,
                        notes: item.notes,
                        trackingStyleRaw: item.trackingStyleRaw
                    )
                    routine.items.append(ri)

                    // Planned rows
                    for (sidx, p) in item.plans.enumerated() {
                        let plan = WorkoutSetPlan(
                            order: sidx,
                            targetReps: p.targetReps,
                            targetWeight: p.targetWeight,
                            weightUnit: p.weightUnit,
                            targetDurationSeconds: p.targetDurationSeconds,
                            targetDistance: p.targetDistance,
                            targetRPE: p.targetRPE,
                            restSeconds: p.restSeconds,
                            routineItem: ri
                        )
                        ri.setPlans.append(plan)
                    }
                }
            }

            try context.save()
            UserDefaults.standard.set(seedVersion, forKey: seedKey)
        } catch {
            // Don’t hard-crash the app on seed issues.
            assertionFailure("Seed failed: \(error)")
        }
    }
}
