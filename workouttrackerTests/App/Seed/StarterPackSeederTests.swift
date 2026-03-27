import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class StarterPackSeederTests: XCTestCase {
    private let versionKey = "workouttracker.starterPackVersion"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: versionKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: versionKey)
        super.tearDown()
    }

    func test_seedIfNeeded_onEmptyStoreSeedsStarterPackAndSetsVersion() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        StarterPackSeeder.seedIfNeeded(context: context)

        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<Exercise>()), 0)
        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<WorkoutRoutine>()), 0)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: versionKey), 3)

        let walking = try fetchExercise(named: "Walking", context: context)
        XCTAssertEqual(walking.catalogKey, "walking")
        XCTAssertEqual(walking.routineRoles, [.warmUp, .coolDown])
    }

    func test_seedIfNeeded_reconcilesExistingStoreWhenVersionAdvances() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let walking = Exercise(name: "Walking")
        context.insert(walking)
        try context.save()

        UserDefaults.standard.set(2, forKey: versionKey)

        StarterPackSeeder.seedIfNeeded(context: context)

        let reloaded = try fetchExercise(named: "Walking", context: context)
        XCTAssertEqual(reloaded.catalogKey, "walking")
        XCTAssertEqual(reloaded.modality, .cardio)
        XCTAssertEqual(reloaded.routineRoles, [.warmUp, .coolDown])
        XCTAssertEqual(UserDefaults.standard.integer(forKey: versionKey), 3)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutRoutine>()), 0, "Existing non-empty stores should reconcile the exercise catalog without auto-importing starter routines.")
        XCTAssertNotNil(try fetchExercise(named: "Breathing Reset", context: context))
    }

    private func fetchExercise(named name: String, context: ModelContext) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try XCTUnwrap(context.fetch(descriptor).first)
    }
}
