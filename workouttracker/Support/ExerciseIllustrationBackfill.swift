import Foundation
import SwiftData

public enum ExerciseIllustrationBackfill {
    private static let migrationKey = "exerciseIllustrationMigration.v2"

    @MainActor
    public static func migrateIfNeeded(context: ModelContext) throws -> Int {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return 0 }

        let catalog = try? SeedCatalog.loadFromBundle()
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        var updatedCount = 0

        for exercise in exercises {
            let matchedSeed = matchedSeedExercise(for: exercise, in: catalog)
            let preferredStableKey = matchedSeed?.illustrationKey.flatMap { key in
                key.isEmpty ? nil : key
            }

            let legacyStableKey = ExerciseIllustrationCatalog.stableKey(
                fromStoredMediaAssetName: exercise.mediaAssetName,
                exerciseName: exercise.name
            )

            let stableKey = preferredStableKey ?? legacyStableKey
            var changed = false

            if exercise.catalogKey == nil, let catalogKey = matchedSeed?.key {
                exercise.catalogKey = catalogKey
                changed = true
            }

            if let stableKey {
                if exercise.mediaKind != .bundledAsset {
                    exercise.mediaKind = .bundledAsset
                    changed = true
                }

                if exercise.mediaAssetName != stableKey {
                    exercise.mediaAssetName = stableKey
                    changed = true
                }
            }

            if changed {
                exercise.updatedAt = Date()
                updatedCount += 1
            }
        }

        if updatedCount > 0 {
            try context.save()
        }

        defaults.set(true, forKey: migrationKey)
        return updatedCount
    }

    private static func matchedSeedExercise(for exercise: Exercise, in catalog: SeedCatalog?) -> SeedCatalog.SeedExercise? {
        guard let catalog else { return nil }

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

        return uniqueSeedMatch(
            in: catalog.exercises,
            where: { seed in
                normalizedLookupValue(seed.name) == normalizedLookupValue(exercise.name)
            }
        )
    }

    private static func uniqueSeedMatch(
        in exercises: [SeedCatalog.SeedExercise],
        where predicate: (SeedCatalog.SeedExercise) -> Bool
    ) -> SeedCatalog.SeedExercise? {
        let matches = exercises.filter(predicate)
        guard matches.count == 1 else { return nil }
        return matches.first
    }

    private static func normalizedLookupValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
