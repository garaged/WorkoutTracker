import Foundation
import SwiftData

public enum ExerciseIllustrationBackfill {
    private static let migrationKey = "exerciseIllustrationMigration.v1"

    @MainActor
    public static func migrateIfNeeded(context: ModelContext) throws -> Int {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return 0 }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        var updatedCount = 0

        for exercise in exercises {
            guard let stableKey = ExerciseIllustrationCatalog.stableKey(
                fromStoredMediaAssetName: exercise.mediaAssetName,
                exerciseName: exercise.name
            ) else {
                continue
            }

            let needsKindUpdate = exercise.mediaKind != .bundledAsset
            let needsNameUpdate = exercise.mediaAssetName != stableKey

            guard needsKindUpdate || needsNameUpdate else { continue }

            exercise.mediaKind = .bundledAsset
            exercise.mediaAssetName = stableKey
            exercise.updatedAt = Date()
            updatedCount += 1
        }

        if updatedCount > 0 {
            try context.save()
        }

        defaults.set(true, forKey: migrationKey)
        return updatedCount
    }
}
