import XCTest
import SwiftData
@testable import workouttracker

final class ProgramPackExportServiceTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try ProgramPackAssetMapStore.save(.empty)
    }

    @MainActor
    func test_exportV2_includesProgramsRoutinesAndExercises() throws {
        let context = try makeInMemoryContext()
        let pack = makeSamplePackV2(programDays: [1])
        _ = try ProgramPackInstallService.installAssets(from: pack, context: context)

        let data = try ProgramPackExportService.exportV2(programs: pack.programs, context: context)

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        dec.dateDecodingStrategy = .iso8601

        let exported = try dec.decode(ProgramPackV2.self, from: data)
        XCTAssertEqual(exported.formatVersion, 2)
        XCTAssertEqual(exported.programs.count, 1)
        XCTAssertFalse(exported.routines.isEmpty)
        XCTAssertFalse(exported.exercises.isEmpty)
    }

    @MainActor
    func test_exportV2_throwsIfProgramMissingRoutineReference() throws {
        let context = try makeInMemoryContext()

        let brokenDay = TrainingDay(index: 1, title: "Broken", blocks: [
            .init(kind: .workout, title: "Workout", estimatedMinutes: 60, reference: nil)
        ])
        let broken = TrainingProgram(slug: "broken", name: "Broken", weeks: [TrainingWeek(index: 1, days: [brokenDay])])

        XCTAssertThrowsError(try ProgramPackExportService.exportV2(programs: [broken], context: context))
    }

    // MARK: - Helpers

    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Activity.self,
            Exercise.self,
            WorkoutRoutine.self,
            WorkoutRoutineItem.self,
            WorkoutSetPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeSamplePackV2(programDays: [Int]) -> ProgramPackV2 {
        let ex = ExerciseDTO(slug: "goblet-squat", name: "Goblet Squat", modality: "strength", instructions: nil, notes: nil, equipmentTags: nil)

        let routine = RoutineDTO(
            slug: "beginner-full-body-a",
            name: "Beginner Full Body A",
            notes: nil,
            items: [
                RoutineItemDTO(
                    order: 1,
                    exerciseSlug: "goblet-squat",
                    trackingStyle: "strength",
                    notes: nil,
                    setPlans: [SetPlanDTO(order: 1, targetReps: 8, targetWeight: nil, weightUnit: "kg", targetDurationSeconds: nil, targetDistance: nil, targetRpe: nil, restSeconds: 90)]
                )
            ]
        )

        let days: [TrainingDay] = programDays.map { idx in
            TrainingDay(index: idx, title: "Full Body A", blocks: [
                .init(kind: .workout, title: "Routine", estimatedMinutes: 60, reference: .init(kind: .routine, slug: "beginner-full-body-a"))
            ])
        }

        let p = TrainingProgram(slug: "sample-program", name: "Sample Program", weeks: [TrainingWeek(index: 1, days: days)])
        return ProgramPackV2(formatVersion: 2, generatedAt: Date(), exercises: [ex], routines: [routine], programs: [p])
    }
}
