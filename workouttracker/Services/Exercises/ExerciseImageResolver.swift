import Foundation

/// Shared lookup for exercise illustration assets.
///
/// Why this lives in `Services/Exercises`:
/// - picker rows and detail surfaces need the same image-resolution rule
/// - it reuses the existing illustration catalog and user-selected illustration set
/// - views should not reimplement catalogKey/mediaAsset fallback logic
@MainActor
enum ExerciseImageResolver {
    static func assetName(
        for exercise: Exercise,
        illustrationSet: ExerciseIllustrationSet? = nil
    ) -> String? {
        assetName(
            catalogKey: exercise.catalogKey,
            mediaAssetName: exercise.mediaAssetName,
            exerciseName: exercise.name,
            illustrationSet: illustrationSet
        )
    }

    static func assetName(
        catalogKey: String?,
        mediaAssetName: String?,
        exerciseName: String,
        illustrationSet: ExerciseIllustrationSet? = nil
    ) -> String? {
        let selectedSet = illustrationSet ?? UserPreferences.shared.exerciseIllustrationSet
        guard let stableKey = ExerciseIllustrationCatalog.stableKey(
            fromCatalogKey: catalogKey,
            storedMediaAssetName: mediaAssetName,
            exerciseName: exerciseName
        ) else {
            return nil
        }

        return ExerciseIllustrationCatalog.assetName(forStableKey: stableKey, set: selectedSet)
    }
}
