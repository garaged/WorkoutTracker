import XCTest
import SwiftData
@testable import workouttracker

final class ProgramPackInstallServiceTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try ProgramPackAssetMapStore.save(.empty)
    }

    @MainActor
    func test_installAssets_createsExercisesRoutinesItemsAndPlans_andUpdatesMap() throws {
        let context = try makeInMemoryContext()
        let pack = makeSamplePackV2(programDays: [1])

        let result = try ProgramPackInstallService.installAssets(from: pack, context: context)
        XCTAssertGreaterThanOrEqual(result.installedExercises, 1)
        XCTAssertGreaterThanOrEqual(result.installedRoutines, 1)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.count, 1)

        let routines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        XCTAssertEqual(routines.count, 1)
        XCTAssertEqual(routines.first?.items.count, 1)

        let plans = try context.fetch(FetchDescriptor<WorkoutSetPlan>())
        XCTAssertEqual(plans.count, 3)

        let map = try ProgramPackAssetMapStore.load()
        XCTAssertNotNil(map.exercisesBySlug["goblet-squat"])
        XCTAssertNotNil(map.routinesBySlug["beginner-full-body-a"])
    }

    @MainActor
    func test_installAssets_isIdempotent_noDuplicateEntities() throws {
        let context = try makeInMemoryContext()
        let pack = makeSamplePackV2(programDays: [1])

        _ = try ProgramPackInstallService.installAssets(from: pack, context: context)
        _ = try ProgramPackInstallService.installAssets(from: pack, context: context)

        XCTAssertEqual((try context.fetch(FetchDescriptor<Exercise>())).count, 1)
        XCTAssertEqual((try context.fetch(FetchDescriptor<WorkoutRoutine>())).count, 1)
        XCTAssertEqual((try context.fetch(FetchDescriptor<WorkoutRoutineItem>())).count, 1)
        XCTAssertEqual((try context.fetch(FetchDescriptor<WorkoutSetPlan>())).count, 3)
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
        let ex = ExerciseDTO(
            slug: "goblet-squat",
            name: "Goblet Squat",
            modality: "strength",
            instructions: nil,
            notes: nil,
            equipmentTags: ["dumbbell"]
        )

        let routine = RoutineDTO(
            slug: "beginner-full-body-a",
            name: "Beginner Full Body A",
            notes: "Smooth reps",
            items: [
                RoutineItemDTO(
                    order: 1,
                    exerciseSlug: "goblet-squat",
                    trackingStyle: "strength",
                    notes: nil,
                    setPlans: [
                        SetPlanDTO(order: 1, targetReps: 8, targetWeight: nil, weightUnit: "kg", targetDurationSeconds: nil, targetDistance: nil, targetRpe: nil, restSeconds: 90),
                        SetPlanDTO(order: 2, targetReps: 8, targetWeight: nil, weightUnit: "kg", targetDurationSeconds: nil, targetDistance: nil, targetRpe: nil, restSeconds: 90),
                        SetPlanDTO(order: 3, targetReps: 8, targetWeight: nil, weightUnit: "kg", targetDurationSeconds: nil, targetDistance: nil, targetRpe: nil, restSeconds: 90)
                    ]
                )
            ]
        )

        let days: [TrainingDay] = programDays.map { idx in
            TrainingDay(
                index: idx,
                title: "Full Body A",
                blocks: [
                    .init(
                        kind: .workout,
                        title: "Routine",
                        estimatedMinutes: 60,
                        reference: .init(kind: .routine, slug: "beginner-full-body-a")
                    )
                ]
            )
        }

        let program = TrainingProgram(
            slug: "sample-program",
            name: "Sample Program",
            level: .beginner,
            weeks: [TrainingWeek(index: 1, title: "Week 1", goal: nil, days: days)]
        )

        return ProgramPackV2(
            formatVersion: 2,
            generatedAt: Date(),
            exercises: [ex],
            routines: [routine],
            programs: [program]
        )
    }
}
