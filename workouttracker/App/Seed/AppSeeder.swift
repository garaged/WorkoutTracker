import Foundation
import SwiftData

@MainActor
enum AppSeeder {
    // Bump when you change the bundled seed JSONs.
    private static let seedVersion = 2
    private static let seedKey = "workouttracker.seedVersion"

    static func seedIfNeeded(context: ModelContext) {
        let current = UserDefaults.standard.integer(forKey: seedKey)
        guard current < seedVersion else { return }

        let existingExerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let existingRoutineCount  = (try? context.fetchCount(FetchDescriptor<WorkoutRoutine>())) ?? 0

        guard existingExerciseCount == 0 && existingRoutineCount == 0 else {
            UserDefaults.standard.set(seedVersion, forKey: seedKey)
            return
        }

        do {
            let catalog = try SeedCatalog.loadFromBundle()

            var exerciseByKey: [String: Exercise] = [:]
            for ex in catalog.exercises {
                let rolesRaw = ex.routineRoles?
                    .compactMap { ExerciseRoutineRole(rawValue: $0) }
                    .sorted { $0.rawValue < $1.rawValue }
                    .map(\.rawValue)
                    .joined(separator: ",")

                let e = Exercise(
                    id: ex.id,
                    name: ex.name,
                    modality: .strength,
                    instructions: ex.instructions,
                    notes: ex.notes,
                    mediaKind: (ex.illustrationKey == nil ? .none : .bundledAsset),
                    mediaAssetName: ex.illustrationKey,
                    mediaURLString: nil,
                    equipmentTagsRaw: (ex.equipmentTags ?? []).joined(separator: ","),
                    routineRolesRaw: rolesRaw?.isEmpty == false ? rolesRaw : nil
                )

                if let modalityRaw = ex.modalityRaw, !modalityRaw.isEmpty {
                    e.modalityRaw = modalityRaw
                }

                context.insert(e)
                exerciseByKey[ex.key] = e
            }

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
            assertionFailure("Seed failed: \(error)")
        }
    }
}
