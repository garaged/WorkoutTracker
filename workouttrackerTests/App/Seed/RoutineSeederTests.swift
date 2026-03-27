import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class RoutineSeederTests: XCTestCase {

    func test_importStarterPack_seedsWarmUpAndCoolDownStarterExercisesWithExpectedMetadata() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        _ = try RoutineSeeder.importStarterPack(context: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let byName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })

        let walking = try XCTUnwrap(byName["Walking"])
        XCTAssertEqual(walking.catalogKey, "walking")
        XCTAssertEqual(walking.modality, .cardio)
        XCTAssertEqual(walking.routineRoles, [.warmUp, .coolDown])
        XCTAssertFalse(walking.isArchived)

        let easyRun = try XCTUnwrap(byName["Easy Run"])
        XCTAssertEqual(easyRun.catalogKey, "easy-run")
        XCTAssertEqual(easyRun.modality, .cardio)
        XCTAssertEqual(easyRun.routineRoles, [.warmUp])

        let mobilityFlow = try XCTUnwrap(byName["Mobility Flow"])
        XCTAssertEqual(mobilityFlow.catalogKey, "mobility-flow")
        XCTAssertEqual(mobilityFlow.modality, .mobility)
        XCTAssertEqual(mobilityFlow.routineRoles, [.warmUp, .coolDown])

        let dynamicStretching = try XCTUnwrap(byName["Dynamic Stretching"])
        XCTAssertEqual(dynamicStretching.catalogKey, "dynamic-stretching")
        XCTAssertEqual(dynamicStretching.modality, .mobility)
        XCTAssertEqual(dynamicStretching.routineRoles, [.warmUp])

        let stretchingFlow = try XCTUnwrap(byName["Stretching Flow"])
        XCTAssertEqual(stretchingFlow.catalogKey, "stretching-flow")
        XCTAssertEqual(stretchingFlow.modality, .mobility)
        XCTAssertEqual(stretchingFlow.routineRoles, [.coolDown])

        let breathingReset = try XCTUnwrap(byName["Breathing Reset"])
        XCTAssertEqual(breathingReset.catalogKey, "breathing-reset")
        XCTAssertEqual(breathingReset.modality, .mobility)
        XCTAssertEqual(breathingReset.routineRoles, [.coolDown])
    }

    func test_importStarterPack_isIdempotentForStarterExercisesAndRoutines() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        _ = try RoutineSeeder.importStarterPack(context: context)
        let firstExerciseCount = try context.fetchCount(FetchDescriptor<Exercise>())
        let firstRoutineCount = try context.fetchCount(FetchDescriptor<WorkoutRoutine>())

        _ = try RoutineSeeder.importStarterPack(context: context)
        let secondExerciseCount = try context.fetchCount(FetchDescriptor<Exercise>())
        let secondRoutineCount = try context.fetchCount(FetchDescriptor<WorkoutRoutine>())

        XCTAssertEqual(secondExerciseCount, firstExerciseCount)
        XCTAssertEqual(secondRoutineCount, firstRoutineCount)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let trackedNames = [
            "Walking",
            "Easy Run",
            "Mobility Flow",
            "Dynamic Stretching",
            "Stretching Flow",
            "Breathing Reset"
        ]

        for name in trackedNames {
            XCTAssertEqual(exercises.filter { $0.name == name }.count, 1, "Expected exactly one seeded exercise named \(name).")
        }
    }

    func test_reconcileStarterExerciseCatalog_backfillsCatalogKeyAndMetadataWithoutOverwritingExistingNotes() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let walking = Exercise(
            name: "Walking",
            modality: .strength,
            notes: "Keep this custom note.",
            mediaKind: .none,
            mediaAssetName: nil,
            equipmentTagsRaw: "",
            routineRolesRaw: nil
        )
        context.insert(walking)
        try context.save()

        _ = try RoutineSeeder.reconcileStarterExerciseCatalog(context: context)

        let reloaded = try fetchExercise(named: "Walking", context: context)
        XCTAssertEqual(reloaded.catalogKey, "walking")
        XCTAssertEqual(reloaded.modality, .cardio)
        XCTAssertEqual(reloaded.routineRoles, [.warmUp, .coolDown])
        XCTAssertEqual(reloaded.notes, "Keep this custom note.")
        XCTAssertEqual(reloaded.mediaAssetName, "walking")
    }

    func test_importStarterPack_usesCatalogKeyForRoutineItemResolutionWhenVisibleNameDiffers() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let localizedBench = Exercise(
            name: "Press de banca",
            catalogKey: "bench-press",
            modality: .strength,
            mediaKind: .bundledAsset,
            mediaAssetName: "bench_press"
        )
        context.insert(localizedBench)
        try context.save()

        _ = try RoutineSeeder.importStarterPack(context: context)

        let routines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        let fullBodyA = try XCTUnwrap(routines.first(where: { $0.name == "Starter — Full Body A" }))
        let benchItem = try XCTUnwrap(fullBodyA.items.first(where: { $0.exercise?.catalogKey == "bench-press" }))
        let benchExercise = try XCTUnwrap(benchItem.exercise)

        XCTAssertEqual(benchExercise.id, localizedBench.id)
        XCTAssertEqual(benchExercise.name, "Press de banca")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 17)
    }

    private func fetchExercise(named name: String, context: ModelContext) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try XCTUnwrap(context.fetch(descriptor).first)
    }
}
