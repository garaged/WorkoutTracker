import XCTest
@testable import workouttracker

final class ProgramPackCodecTests: XCTestCase {

    func test_encodeDecode_roundTripsPack() throws {
        let pack = makeSamplePack()

        let data = try ProgramPackCodec.encode(pack)
        let decoded = try ProgramPackCodec.decode(data)

        XCTAssertEqual(decoded.schemaVersion, ProgramPack.supportedSchemaVersion)
        XCTAssertEqual(decoded.packID, "sample-pack")
        XCTAssertEqual(decoded.programs.map(\.slug), ["sample-program"])
        XCTAssertEqual(decoded.routines.map(\.slug), ["sample-routine"])
        XCTAssertEqual(decoded.exercises.map(\.slug), ["goblet-squat"])
    }

    func test_decode_rejectsUnsupportedSchemaVersion() {
        let json = #"""
        {
          "format_version": 99,
          "pack_id": "unsupported-pack",
          "generated_at": "2026-03-01T00:00:00Z",
          "programs": []
        }
        """#

        XCTAssertThrowsError(try ProgramPackCodec.decode(Data(json.utf8))) { error in
            XCTAssertEqual(error as? ProgramPackCodec.CodecError, .unsupportedSchemaVersion(99))
        }
    }

    private func makeSamplePack() -> ProgramPack {
        let exercise = ExerciseDTO(
            slug: "goblet-squat",
            name: "Goblet Squat",
            catalogKey: "goblet-squat",
            modality: "strength",
            equipmentTags: ["dumbbell"]
        )

        let routine = RoutineDTO(
            slug: "sample-routine",
            name: "Sample Routine",
            items: [
                RoutineItemDTO(
                    order: 1,
                    exerciseSlug: "goblet-squat",
                    trackingStyle: "strength",
                    setPlans: [
                        SetPlanDTO(order: 1, targetReps: 8, weightUnit: "kg", restSeconds: 90)
                    ]
                )
            ]
        )

        let day = TrainingDay(
            index: 1,
            title: "Day 1",
            blocks: [
                .init(kind: .workout, title: "Routine", estimatedMinutes: 45, reference: .init(kind: .routine, slug: "sample-routine"))
            ]
        )
        let week = TrainingWeek(index: 1, title: "Week 1", days: [day])
        let program = TrainingProgram(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, slug: "sample-program", name: "Sample Program", weeks: [week])

        return ProgramPack(
            schemaVersion: ProgramPack.supportedSchemaVersion,
            packID: "sample-pack",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercises: [exercise],
            routines: [routine],
            programs: [program]
        )
    }
}
