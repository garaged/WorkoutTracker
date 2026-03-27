import XCTest
@testable import workouttracker

final class SeedCatalogDecodingTests: XCTestCase {

    func test_decodeExerciseMetadata_supportsRoutineRolesAndIllustrationKey() throws {
        let json = #"""
        {
          "exercises": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "key": "walking",
              "name": "Walking",
              "notes": "Easy pace.",
              "modalityRaw": "cardio",
              "instructions": "Stay conversational.",
              "equipmentTags": ["cardio"],
              "routineRoles": ["warmUp", "coolDown"],
              "illustrationKey": "walking"
            }
          ],
          "routines": []
        }
        """#

        let data = try XCTUnwrap(json.data(using: .utf8))
        let catalog = try JSONDecoder().decode(SeedCatalog.self, from: data)
        let exercise = try XCTUnwrap(catalog.exercises.first)

        XCTAssertEqual(exercise.key, "walking")
        XCTAssertEqual(exercise.name, "Walking")
        XCTAssertEqual(exercise.modalityRaw, "cardio")
        XCTAssertEqual(exercise.instructions, "Stay conversational.")
        XCTAssertEqual(exercise.equipmentTags ?? [], ["cardio"])
        XCTAssertEqual(exercise.routineRoles ?? [], ["warmUp", "coolDown"])
        XCTAssertEqual(exercise.illustrationKey, "walking")
        XCTAssertEqual(catalog.exercise(forKey: "walking")?.name, "Walking")
    }

    func test_seedCatalogSource_hasUniqueStableExerciseKeys() throws {
        let catalog = try loadCatalogFromSourceTree()

        XCTAssertFalse(catalog.exercises.isEmpty, "Expected bundled seed source to contain exercises.")

        let keys = catalog.exercises.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "Expected seed exercise keys to be unique.")
        XCTAssertFalse(
            keys.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
            "Expected all seed exercise keys to be non-empty."
        )
    }

    private func loadCatalogFromSourceTree() throws -> SeedCatalog {
        let testFileURL = URL(fileURLWithPath: #filePath)
        var searchURL = testFileURL.deletingLastPathComponent()

        for _ in 0..<10 {
            let candidate = searchURL
                .appendingPathComponent("workouttracker", isDirectory: true)
                .appendingPathComponent("App", isDirectory: true)
                .appendingPathComponent("Seed", isDirectory: true)
                .appendingPathComponent("seed_v1.json", isDirectory: false)

            if FileManager.default.fileExists(atPath: candidate.path) {
                let data = try Data(contentsOf: candidate)
                return try JSONDecoder().decode(SeedCatalog.self, from: data)
            }

            let parent = searchURL.deletingLastPathComponent()
            if parent.path == searchURL.path { break }
            searchURL = parent
        }

        XCTFail(
            """
            Missing seed_v1.json in source tree relative to test file.
            Starting from:
            \(testFileURL.path)
            """
        )

        throw NSError(
            domain: "SeedCatalogDecodingTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing seed_v1.json in source tree"]
        )
    }
}
