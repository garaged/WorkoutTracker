import Foundation
import SwiftData

@MainActor
enum AppSeeder {
    // Bump when you change the bundled seed JSONs or reconciliation behavior.
    private static let seedVersion = 3
    private static let seedKey = "workouttracker.seedVersion"

    static func seedIfNeeded(context: ModelContext) {
        let current = UserDefaults.standard.integer(forKey: seedKey)
        guard current < seedVersion else { return }

        do {
            let catalog = try SeedCatalog.loadFromBundle()

            let existingExerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
            let existingRoutineCount  = (try? context.fetchCount(FetchDescriptor<WorkoutRoutine>())) ?? 0

            if existingExerciseCount == 0 && existingRoutineCount == 0 {
                try seedFreshStore(context: context, catalog: catalog)
            } else {
                try reconcileExistingCatalogExercises(context: context, catalog: catalog)
            }

            UserDefaults.standard.set(seedVersion, forKey: seedKey)
        } catch {
            assertionFailure("Seed failed: \(error)")
        }
    }

    private static func seedFreshStore(context: ModelContext, catalog: SeedCatalog) throws {
        var exerciseByKey: [String: Exercise] = [:]

        for ex in catalog.exercises {
            let exercise = makeExercise(from: ex)
            context.insert(exercise)
            exerciseByKey[ex.key] = exercise
        }

        for routineDef in catalog.routines {
            let routine = WorkoutRoutine(id: routineDef.id, name: routineDef.name)
            context.insert(routine)

            for (idx, itemDef) in routineDef.items.enumerated() {
                guard let exercise = exerciseByKey[itemDef.exerciseKey] else { continue }

                let item = WorkoutRoutineItem(
                    order: idx,
                    routine: routine,
                    exercise: exercise,
                    notes: itemDef.notes,
                    trackingStyleRaw: itemDef.trackingStyleRaw
                )
                routine.items.append(item)

                for (setIdx, planDef) in itemDef.plans.enumerated() {
                    let plan = WorkoutSetPlan(
                        order: setIdx,
                        targetReps: planDef.targetReps,
                        targetWeight: planDef.targetWeight,
                        weightUnit: planDef.weightUnit,
                        targetDurationSeconds: planDef.targetDurationSeconds,
                        targetDistance: planDef.targetDistance,
                        targetRPE: planDef.targetRPE,
                        restSeconds: planDef.restSeconds,
                        routineItem: item
                    )
                    item.setPlans.append(plan)
                }
            }
        }

        try context.save()
    }

    private static func reconcileExistingCatalogExercises(context: ModelContext, catalog: SeedCatalog) throws {
        let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
        guard !existingExercises.isEmpty else { return }

        var changed = false

        for exercise in existingExercises {
            guard let seedExercise = matchedSeedExercise(for: exercise, in: catalog) else { continue }
            if applyCatalogMetadata(seedExercise, to: exercise) {
                changed = true
            }
        }

        if changed {
            try context.save()
        }
    }

    private static func makeExercise(from seed: SeedCatalog.SeedExercise) -> Exercise {
        let hasIllustration = !(seed.illustrationKey?.isEmpty ?? true)
        let rolesRaw = seed.routineRoles?
            .compactMap { ExerciseRoutineRole(rawValue: $0) }
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.rawValue)
            .joined(separator: ",")

        let exercise = Exercise(
            id: seed.id,
            name: seed.name,
            catalogKey: seed.key,
            modality: .strength,
            instructions: seed.instructions,
            notes: seed.notes,
            mediaKind: hasIllustration ? .bundledAsset : .none,
            mediaAssetName: seed.illustrationKey,
            mediaURLString: nil,
            equipmentTagsRaw: (seed.equipmentTags ?? []).joined(separator: ","),
            routineRolesRaw: rolesRaw?.isEmpty == false ? rolesRaw : nil
        )

        if let modalityRaw = seed.modalityRaw, !modalityRaw.isEmpty {
            exercise.modalityRaw = modalityRaw
        }

        return exercise
    }

    private static func matchedSeedExercise(for exercise: Exercise, in catalog: SeedCatalog) -> SeedCatalog.SeedExercise? {
        if let catalogKey = exercise.catalogKey,
           let exact = catalog.exercise(forKey: catalogKey) {
            return exact
        }

        if let mediaAssetName = exercise.mediaAssetName,
           let mediaMatch = uniqueSeedMatch(
               in: catalog.exercises,
               where: { seed in
                   seed.illustrationKey == mediaAssetName
               }
           ) {
            return mediaMatch
        }
        return uniqueSeedMatch(in: catalog.exercises) { seed in
            normalizedLookupValue(seed.name) == normalizedLookupValue(exercise.name)
        }
    }

    private static func uniqueSeedMatch(
        in exercises: [SeedCatalog.SeedExercise],
        where predicate: (SeedCatalog.SeedExercise) -> Bool
    ) -> SeedCatalog.SeedExercise? {
        let matches = exercises.filter(predicate)
        guard matches.count == 1 else { return nil }
        return matches.first
    }

    @discardableResult
    private static func applyCatalogMetadata(_ seed: SeedCatalog.SeedExercise, to exercise: Exercise) -> Bool {
        var changed = false

        if exercise.catalogKey == nil {
            exercise.catalogKey = seed.key
            changed = true
        }

        if let modalityRaw = seed.modalityRaw, !modalityRaw.isEmpty, exercise.modalityRaw != modalityRaw {
            exercise.modalityRaw = modalityRaw
            changed = true
        }

        let normalizedEquipment = (seed.equipmentTags ?? []).joined(separator: ",")
        if exercise.equipmentTagsRaw != normalizedEquipment {
            exercise.equipmentTagsRaw = normalizedEquipment
            changed = true
        }

        let desiredRolesRaw = joinedRoutineRoles(seed.routineRoles ?? [])
        if exercise.routineRolesRaw != desiredRolesRaw {
            exercise.routineRolesRaw = desiredRolesRaw
            changed = true
        }

        if exercise.instructions == nil, let instructions = seed.instructions, !instructions.isEmpty {
            exercise.instructions = instructions
            changed = true
        }

        if exercise.notes == nil, let notes = seed.notes, !notes.isEmpty {
            exercise.notes = notes
            changed = true
        }

        if let illustrationKey = seed.illustrationKey, !illustrationKey.isEmpty {
            if exercise.mediaKind != .bundledAsset {
                exercise.mediaKind = .bundledAsset
                changed = true
            }
            if exercise.mediaAssetName != illustrationKey {
                exercise.mediaAssetName = illustrationKey
                changed = true
            }
        }

        if changed {
            exercise.updatedAt = Date()
        }

        return changed
    }

    private static func joinedRoutineRoles(_ roles: [String]) -> String? {
        let values = roles
            .compactMap { ExerciseRoutineRole(rawValue: $0) }
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.rawValue)
        return values.isEmpty ? nil : values.joined(separator: ",")
    }

    private static func normalizedLookupValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
