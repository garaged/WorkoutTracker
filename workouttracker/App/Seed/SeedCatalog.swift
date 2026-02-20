import Foundation

struct SeedCatalog: Codable {
    struct SeedExercise: Codable {
        let id: UUID
        let key: String        // stable reference for routines
        let name: String
        let notes: String?
        // Add fields here if your Exercise model supports them:
        // let modality: String?
        // let muscleGroups: [String]?
        // let equipment: [String]?
    }

    struct SeedPlan: Codable {
        let targetReps: Int?
        let targetWeight: Double?
        let weightUnit: WeightUnit
        let targetDurationSeconds: Int?
        let targetDistance: Double?
        let targetRPE: Double?
        let restSeconds: Int?
    }

    struct SeedRoutineItem: Codable {
        let exerciseKey: String
        let trackingStyleRaw: String
        let notes: String?
        let plans: [SeedPlan]
    }

    struct SeedRoutine: Codable {
        let id: UUID
        let name: String
        let items: [SeedRoutineItem]
    }

    let exercises: [SeedExercise]
    let routines: [SeedRoutine]

    static func loadFromBundle() throws -> SeedCatalog {
        guard let url = Bundle.main.url(forResource: "seed_v1", withExtension: "json") else {
            throw NSError(domain: "Seed", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing seed_v1.json in bundle"])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SeedCatalog.self, from: data)
    }
}
