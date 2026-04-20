import XCTest
@testable import workouttracker

final class ProgramPackValidatorTests: XCTestCase {

    func test_validate_rejectsDuplicateProgramIDs() {
        let duplicateID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let first = makeProgram(id: duplicateID, slug: "sample-program")
        let second = makeProgram(id: duplicateID, slug: "sample-program-copy")
        let pack = makeBasePack(programs: [first, second])

        let report = ProgramPackValidator.validate(pack)

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.code == .duplicateProgramID })
    }

    func test_validate_rejectsBrokenRoutineReferences() {
        var program = makeProgram(id: UUID(), slug: "sample-program")
        program.weeks[0].days[0].blocks = [
            .init(kind: .workout, title: "Missing", estimatedMinutes: 45, reference: .init(kind: .routine, slug: "missing-routine"))
        ]
        let pack = makeBasePack(programs: [program])

        let report = ProgramPackValidator.validate(pack)

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.code == .missingRoutineReference })
    }

    func test_validate_rejectsInvalidOrdering() {
        var routine = makeRoutine()
        routine.items = [
            RoutineItemDTO(order: 2, exerciseSlug: "goblet-squat", trackingStyle: "strength", setPlans: [SetPlanDTO(order: 1, targetReps: 8)]),
            RoutineItemDTO(order: 1, exerciseSlug: "goblet-squat", trackingStyle: "strength", setPlans: [SetPlanDTO(order: 1, targetReps: 8)])
        ]
        let pack = ProgramPack(
            schemaVersion: ProgramPack.supportedSchemaVersion,
            packID: "sample-pack",
            generatedAt: nil,
            exercises: [makeExercise()],
            routines: [routine],
            programs: [makeProgram(id: UUID(), slug: "sample-program")]
        )

        let report = ProgramPackValidator.validate(pack)

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.code == .invalidOrdering })
    }

    func test_validate_rejectsInvalidNumericAndRuleConfiguration() {
        var program = makeProgram(id: UUID(), slug: "sample-program")
        program.weeks[0].days[0].prescriptions = [
            ProgramPrescription(
                order: 1,
                exerciseNameSnapshot: "Goblet Squat",
                targetSets: 0,
                targetReps: -1,
                targetWeight: -10,
                targetRPE: 12,
                progressionRules: [.fixedLoadIncrease(step: 0)]
            )
        ]
        let pack = makeBasePack(programs: [program])

        let report = ProgramPackValidator.validate(pack)

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.code == .invalidNumericRange })
        XCTAssertTrue(report.errors.contains { $0.code == .invalidProgressionRule })
    }

    private func makeBasePack(programs: [TrainingProgram]) -> ProgramPack {
        ProgramPack(
            schemaVersion: ProgramPack.supportedSchemaVersion,
            packID: "sample-pack",
            generatedAt: nil,
            exercises: [makeExercise()],
            routines: [makeRoutine()],
            programs: programs
        )
    }

    private func makeExercise() -> ExerciseDTO {
        ExerciseDTO(
            slug: "goblet-squat",
            name: "Goblet Squat",
            catalogKey: "goblet-squat",
            modality: "strength"
        )
    }

    private func makeRoutine() -> RoutineDTO {
        RoutineDTO(
            slug: "sample-routine",
            name: "Sample Routine",
            items: [
                RoutineItemDTO(
                    order: 1,
                    exerciseSlug: "goblet-squat",
                    trackingStyle: "strength",
                    setPlans: [SetPlanDTO(order: 1, targetReps: 8, weightUnit: "kg")]
                )
            ]
        )
    }

    private func makeProgram(id: UUID, slug: String) -> TrainingProgram {
        let day = TrainingDay(
            index: 1,
            title: "Day 1",
            blocks: [
                .init(kind: .workout, title: "Routine", estimatedMinutes: 45, reference: .init(kind: .routine, slug: "sample-routine"))
            ]
        )
        let week = TrainingWeek(index: 1, title: "Week 1", days: [day])
        return TrainingProgram(id: id, slug: slug, name: "Sample Program", weeks: [week])
    }
}
