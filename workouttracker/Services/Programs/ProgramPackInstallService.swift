import Foundation
import Combine
import SwiftData

@MainActor
enum ProgramPackInstallService {

    struct InstallResult: Sendable {
        var installedExercises: Int
        var installedRoutines: Int
    }

    enum InstallError: LocalizedError {
        case invalidPackVersion(Int)

        var errorDescription: String? {
            switch self {
            case .invalidPackVersion(let v): return "Unsupported pack version \(v)."
            }
        }
    }

    static func installAssets(from pack: ProgramPackV2, context: ModelContext) throws -> InstallResult {
        guard pack.formatVersion == 2 else { throw InstallError.invalidPackVersion(pack.formatVersion) }

        var map = (try? ProgramPackAssetMapStore.load()) ?? .empty

        // Fetch existing entities once
        let existingExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingRoutines  = (try? context.fetch(FetchDescriptor<WorkoutRoutine>())) ?? []

        let exercisesByLowerName: [String: Exercise] = Dictionary(uniqueKeysWithValues: existingExercises.map { ($0.name.lowercased(), $0) })
        let routinesByLowerName: [String: WorkoutRoutine] = Dictionary(uniqueKeysWithValues: existingRoutines.map { ($0.name.lowercased(), $0) })

        // Keep direct object references while installing so we never end up with nil relationships.
        var exerciseBySlug: [String: Exercise] = [:]
        var routineBySlug: [String: WorkoutRoutine] = [:]

        var installedExercises = 0
        var installedRoutines = 0

        // 1) Exercises (slug → Exercise instance)
        for dto in pack.exercises {
            let slug = dto.slug.lowercased()

            // If mapping exists and object exists, use it.
            if let id = map.exercisesBySlug[slug],
               let ex = existingExercises.first(where: { $0.id == id }) {
                exerciseBySlug[slug] = ex
                continue
            }

            // If a same-named exercise exists, map to it.
            if let ex = exercisesByLowerName[dto.name.lowercased()] {
                map.exercisesBySlug[slug] = ex.id
                exerciseBySlug[slug] = ex
                continue
            }

            // Otherwise create a new exercise.
            let modality = ExerciseModality(rawValue: dto.modality) ?? .strength
            let ex = Exercise(
                name: dto.name,
                modality: modality,
                instructions: dto.instructions,
                notes: dto.notes
            )
            if let tags = dto.equipmentTags, !tags.isEmpty {
                ex.setEquipmentTags(tags)
            }

            context.insert(ex)
            map.exercisesBySlug[slug] = ex.id
            exerciseBySlug[slug] = ex
            installedExercises += 1
        }

        // 2) Routines (slug → WorkoutRoutine instance), and populate items if routine is new OR empty
        for rDTO in pack.routines {
            let slug = rDTO.slug.lowercased()

            // Prefer mapped routine if it exists
            if let id = map.routinesBySlug[slug],
               let routine = existingRoutines.first(where: { $0.id == id }) {
                routineBySlug[slug] = routine

                // If it’s empty, it’s safe to populate (fixes “schedulable but no exercises”)
                if routine.items.isEmpty {
                    populate(routine: routine, from: rDTO, exerciseBySlug: &exerciseBySlug, map: &map, context: context)
                    installedRoutines += 1
                }
                continue
            }

            // Otherwise if a same-named routine exists, map to it (and populate if empty)
            if let routine = routinesByLowerName[rDTO.name.lowercased()] {
                map.routinesBySlug[slug] = routine.id
                routineBySlug[slug] = routine
                if routine.items.isEmpty {
                    populate(routine: routine, from: rDTO, exerciseBySlug: &exerciseBySlug, map: &map, context: context)
                    installedRoutines += 1
                }
                continue
            }

            // Else create routine and populate
            let routine = WorkoutRoutine(name: rDTO.name, notes: rDTO.notes)
            context.insert(routine)
            map.routinesBySlug[slug] = routine.id
            routineBySlug[slug] = routine

            populate(routine: routine, from: rDTO, exerciseBySlug: &exerciseBySlug, map: &map, context: context)
            installedRoutines += 1
        }

        try context.save()
        try ProgramPackAssetMapStore.save(map)

        return InstallResult(installedExercises: installedExercises, installedRoutines: installedRoutines)
    }

    // MARK: - Populate helpers

    private static func populate(
        routine: WorkoutRoutine,
        from dto: RoutineDTO,
        exerciseBySlug: inout [String: Exercise],
        map: inout ProgramPackAssetMap,
        context: ModelContext
    ) {
        // Clear any partial children to avoid duplicates when populating an empty routine.
        if !routine.items.isEmpty {
            for item in routine.items { context.delete(item) }
            routine.items.removeAll()
        }

        for itemDTO in dto.items.sorted(by: { $0.order < $1.order }) {
            let exSlug = itemDTO.exerciseSlug.lowercased()

            // Resolve or create the exercise deterministically
            let ex: Exercise = {
                if let existing = exerciseBySlug[exSlug] { return existing }

                // If mapping exists but object wasn't in initial fetch, fetch it now
                if let id = map.exercisesBySlug[exSlug] {
                    if let fetched = try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })).first {
                        exerciseBySlug[exSlug] = fetched
                        return fetched
                    }
                }

                // Create placeholder (should be rare for seed/catalog, but keeps packs resilient)
                let placeholder = Exercise(name: exSlug.replacingOccurrences(of: "-", with: " ").capitalized)
                context.insert(placeholder)
                map.exercisesBySlug[exSlug] = placeholder.id
                exerciseBySlug[exSlug] = placeholder
                return placeholder
            }()

            let item = WorkoutRoutineItem(
                order: itemDTO.order,
                routine: routine,
                exercise: ex,
                notes: itemDTO.notes,
                trackingStyleRaw: itemDTO.trackingStyle
            )
            routine.items.append(item)
            context.insert(item)

            for p in itemDTO.setPlans.sorted(by: { $0.order < $1.order }) {
                let plan = WorkoutSetPlan(
                    order: p.order,
                    targetReps: p.targetReps,
                    targetWeight: p.targetWeight,
                    weightUnit: WeightUnit(rawValue: p.weightUnit ?? "kg") ?? .kg,
                    targetDurationSeconds: p.targetDurationSeconds,
                    targetDistance: p.targetDistance,
                    targetRPE: p.targetRpe,
                    restSeconds: p.restSeconds,
                    routineItem: item
                )
                item.setPlans.append(plan)
                context.insert(plan)
            }
        }

        routine.updatedAt = Date()
    }
}
