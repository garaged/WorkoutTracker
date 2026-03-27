import XCTest
@testable import workouttracker

final class ProgramPackV2CompatibilityTests: XCTestCase {

    func test_decodeLegacyExerciseDTO_withoutCatalogKey_stillSucceeds() throws {
        let json = #"""
        {
          "format_version": 2,
          "generated_at": "2026-03-01T00:00:00Z",
          "exercises": [
            {
              "slug": "bench-press",
              "name": "Bench Press",
              "modality": "strength"
            }
          ],
          "routines": [],
          "programs": []
        }
        """#

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let pack = try decoder.decode(ProgramPackV2.self, from: Data(json.utf8))
        XCTAssertEqual(pack.exercises.first?.slug, "bench-press")
        XCTAssertNil(pack.exercises.first?.catalogKey)
    }

    func test_stableExerciseSlug_prefersCatalogKey_forBuiltIns() {
        XCTAssertEqual(
            ProgramPackHelpers.stableExerciseSlug(name: "Press de banca", catalogKey: "bench-press"),
            "bench-press"
        )
    }

    func test_stableExerciseSlug_usesVisibleName_forCustomExercises() {
        XCTAssertEqual(
            ProgramPackHelpers.stableExerciseSlug(name: "My Custom Press", catalogKey: nil),
            "my-custom-press"
        )
    }
}
