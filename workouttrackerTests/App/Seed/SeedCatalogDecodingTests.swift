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
    }
}
