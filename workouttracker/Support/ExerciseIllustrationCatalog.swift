import Foundation

/// Central lookup for converting stable exercise keys into asset names.
public enum ExerciseIllustrationCatalog {

    public struct Assets {
        public let dummyV1: String
        public let femaleV1: String
        public let maleV1: String
    }

    public static func exerciseKey(for exerciseName: String) -> String? {
        let normalized = normalize(exerciseName)
        if let exact = aliases[normalized] {
            return exact
        }
        return nil
    }

    public static func assetName(for exerciseName: String, set: ExerciseIllustrationSet) -> String? {
        guard let key = exerciseKey(for: exerciseName) else {
            return nil
        }
        return assetName(forStableKey: key, set: set)
    }

    public static func assetName(forExerciseKey key: String, set: ExerciseIllustrationSet) -> String? {
        assetName(forStableKey: key, set: set)
    }

    public static func assetName(forStableKey key: String, set: ExerciseIllustrationSet) -> String? {
        guard let assets = assetMap[normalizedStableKey(key)] else { return nil }
        switch set {
        case .dummyV1: return assets.dummyV1
        case .femaleV1: return assets.femaleV1
        case .maleV1: return assets.maleV1
        }
    }

    public static func stableKey(
        fromCatalogKey catalogKey: String?,
        storedMediaAssetName stored: String?,
        exerciseName: String
    ) -> String? {
        if let catalogKey,
           let normalizedCatalogKey = normalizedStableKeyIfKnown(catalogKey) {
            return normalizedCatalogKey
        }

        let rawStored = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawStored.isEmpty {
            if let normalizedStored = normalizedStableKeyIfKnown(rawStored) {
                return normalizedStored
            }

            if let reverse = reverseAssetMap[rawStored] {
                return reverse
            }

            if catalogKey == nil, let alias = exerciseKey(for: rawStored) {
                return alias
            }
        }

        guard catalogKey == nil else {
            return nil
        }

        return exerciseKey(for: exerciseName)
    }

    public static func stableKey(
        fromStoredMediaAssetName stored: String?,
        exerciseName: String
    ) -> String? {
        stableKey(fromCatalogKey: nil, storedMediaAssetName: stored, exerciseName: exerciseName)
    }

    private static func normalizedStableKeyIfKnown(_ raw: String) -> String? {
        let normalized = normalizedStableKey(raw)
        if assetMap[normalized] != nil {
            return normalized
        }
        return nil
    }

    public static func normalizedStableKey(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "—", with: "-")
    }

    private static let aliases: [String: String] = [
        "back squat": "back_squat",
        "bench press": "bench_press",
        "deadlift": "deadlift",
        "overhead press": "overhead_press",
        "barbell row": "barbell_row",
        "lat pulldown": "lat_pulldown",
        "pull-up": "pull_up",
        "bicep curl": "bicep_curl",
        "triceps pushdown": "triceps_pushdown",
        "plank": "plank",
        "running": "running",
        "walking": "walking",
        "mobility flow": "mobility_flow",
    ]

    private static let assetMap: [String: Assets] = [
        "back_squat": .init(
            dummyV1: "exercise_back_squat_dummy_v1",
            femaleV1: "exercise_back_squat_female_v1",
            maleV1: "exercise_back_squat_male_v1"
        ),
        "bench_press": .init(
            dummyV1: "exercise_bench_press_dummy_v1",
            femaleV1: "exercise_bench_press_female_v1",
            maleV1: "exercise_bench_press_male_v1"
        ),
        "deadlift": .init(
            dummyV1: "exercise_deadlift_dummy_v1",
            femaleV1: "exercise_deadlift_female_v1",
            maleV1: "exercise_deadlift_male_v1"
        ),
        "overhead_press": .init(
            dummyV1: "exercise_overhead_press_dummy_v1",
            femaleV1: "exercise_overhead_press_female_v1",
            maleV1: "exercise_overhead_press_male_v1"
        ),
        "barbell_row": .init(
            dummyV1: "exercise_barbell_row_dummy_v1",
            femaleV1: "exercise_barbell_row_female_v1",
            maleV1: "exercise_barbell_row_male_v1"
        ),
        "lat_pulldown": .init(
            dummyV1: "exercise_lat_pulldown_dummy_v1",
            femaleV1: "exercise_lat_pulldown_female_v1",
            maleV1: "exercise_lat_pulldown_male_v1"
        ),
        "pull_up": .init(
            dummyV1: "exercise_pull_up_dummy_v1",
            femaleV1: "exercise_pull_up_female_v1",
            maleV1: "exercise_pull_up_male_v1"
        ),
        "bicep_curl": .init(
            dummyV1: "exercise_bicep_curl_dummy_v1",
            femaleV1: "exercise_bicep_curl_female_v1",
            maleV1: "exercise_bicep_curl_male_v1"
        ),
        "triceps_pushdown": .init(
            dummyV1: "exercise_triceps_pushdown_dummy_v1",
            femaleV1: "exercise_triceps_pushdown_female_v1",
            maleV1: "exercise_triceps_pushdown_male_v1"
        ),
        "plank": .init(
            dummyV1: "exercise_plank_dummy_v1",
            femaleV1: "exercise_plank_female_v1",
            maleV1: "exercise_plank_male_v1"
        ),
        "running": .init(
            dummyV1: "exercise_running_dummy_v1",
            femaleV1: "exercise_running_female_v1",
            maleV1: "exercise_running_male_v1"
        ),
        "walking": .init(
            dummyV1: "exercise_walking_dummy_v1",
            femaleV1: "exercise_walking_female_v1",
            maleV1: "exercise_walking_male_v1"
        ),
        "mobility_flow": .init(
            dummyV1: "exercise_mobility_flow_dummy_v1",
            femaleV1: "exercise_mobility_flow_female_v1",
            maleV1: "exercise_mobility_flow_male_v1"
        ),
    ]

    private static let reverseAssetMap: [String: String] = {
        var result: [String: String] = [:]

        for (key, assets) in assetMap {
            result[assets.dummyV1] = key
            result[assets.femaleV1] = key
            result[assets.maleV1] = key
        }

        return result
    }()
}
