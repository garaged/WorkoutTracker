import XCTest
import SwiftData
@testable import workouttracker

final class ProgramSchedulingServiceTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try ProgramPackAssetMapStore.save(.empty)
    }

    @MainActor
    func test_schedule_createsWorkoutsAndRest_betweenActiveDays() throws {
        let context = try makeInMemoryContext()
        let pack = makeSamplePackV2(programDays: [1, 3])
        _ = try ProgramPackInstallService.installAssets(from: pack, context: context)

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let startTime = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startDate))

        let program = pack.programs[0]
        let options = ProgramSchedulingService.Options(
            startDate: startDate,
            startTime: startTime,
            includeRestDays: true,
            conflictStrategy: .skipConflicts
        )

        let result = try ProgramSchedulingService.schedule(program: program, options: options, context: context)
        XCTAssertEqual(result.skipped, 0)

        let activities = try context.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(activities.count, 3)

        let workouts = activities.filter { $0.kind == .workout }
        let rests = activities.filter { $0.isAllDay && $0.kind != .workout }

        XCTAssertEqual(workouts.count, 2)
        XCTAssertEqual(rests.count, 1)
        XCTAssertTrue(workouts.allSatisfy { !$0.isAllDay })
        XCTAssertTrue(workouts.allSatisfy { $0.workoutRoutineId != nil })
    }

    @MainActor
    func test_schedule_throwsWhenRoutinesMissing() throws {
        let context = try makeInMemoryContext()
        try ProgramPackAssetMapStore.save(.empty)

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let startTime = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startDate))

        let pack = makeSamplePackV2(programDays: [1])
        let program = pack.programs[0]

        let options = ProgramSchedulingService.Options(
            startDate: startDate,
            startTime: startTime,
            includeRestDays: true,
            conflictStrategy: .skipConflicts
        )

        // Preview should indicate missing routines (V2 rule)
        let preview = ProgramSchedulingService.preview(program: program, options: options)
        XCTAssertFalse(preview.isSchedulable)

        XCTAssertThrowsError(try ProgramSchedulingService.schedule(program: program, options: options, context: context))
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
            equipmentTags: nil
        )

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
                    setPlans: [
                        SetPlanDTO(
                            order: 1,
                            targetReps: 8,
                            targetWeight: nil,
                            weightUnit: "kg",
                            targetDurationSeconds: nil,
                            targetDistance: nil,
                            targetRpe: nil,
                            restSeconds: 90
                        )
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
            weeks: [TrainingWeek(index: 1, days: days)]
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
