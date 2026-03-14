import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class RoutineLinkedModelPersistenceTests: XCTestCase {

    func test_routineCanPersistWarmUpAndCoolDownLinks() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let warmUp = WorkoutRoutine(name: "Warm-Up")
        let main = WorkoutRoutine(name: "Main")
        let coolDown = WorkoutRoutine(name: "Cool-Down")

        [warmUp, main, coolDown].forEach(context.insert)

        main.warmUpRoutine = warmUp
        main.coolDownRoutine = coolDown
        try context.save()

        let fetched = try fetchRoutine(id: main.id, context: context)
        XCTAssertEqual(fetched.warmUpRoutine?.id, warmUp.id)
        XCTAssertEqual(fetched.coolDownRoutine?.id, coolDown.id)
    }

    func test_deletingLinkedRoutine_nullifiesRelationshipInsteadOfDeletingParent() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let warmUp = WorkoutRoutine(name: "Warm-Up")
        let main = WorkoutRoutine(name: "Main")
        context.insert(warmUp)
        context.insert(main)

        main.warmUpRoutine = warmUp
        try context.save()

        context.delete(warmUp)
        try context.save()

        let fetched = try fetchRoutine(id: main.id, context: context)
        XCTAssertNil(fetched.warmUpRoutine)
        XCTAssertEqual(fetched.name, "Main")
    }

    func test_segmentKind_defaultsToMainWhenRawValueIsMissing() {
        let sessionExercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Bench Press"
        )

        XCTAssertNil(sessionExercise.segmentKindRaw)
        XCTAssertEqual(sessionExercise.segmentKind, .main)
    }

    func test_segmentKind_persistsWarmUpAndCoolDownValues() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let session = WorkoutSession(startedAt: Date())
        context.insert(session)

        let warmUp = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Bike",
            segmentKind: .warmUp,
            session: session
        )
        let coolDown = WorkoutSessionExercise(
            order: 1,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Walk",
            segmentKind: .coolDown,
            session: session
        )

        context.insert(warmUp)
        context.insert(coolDown)
        session.exercises = [warmUp, coolDown]
        try context.save()

        let reloaded = try context.fetch(FetchDescriptor<WorkoutSessionExercise>()).sorted { $0.order < $1.order }
        XCTAssertEqual(reloaded.map(\.segmentKind), [.warmUp, .coolDown])
        XCTAssertEqual(reloaded.map(\.segmentKindRaw), [SessionSegmentKind.warmUp.rawValue, SessionSegmentKind.coolDown.rawValue])
    }

    private func fetchRoutine(id: UUID, context: ModelContext) throws -> WorkoutRoutine {
        let descriptor = FetchDescriptor<WorkoutRoutine>(predicate: #Predicate { $0.id == id })
        return try XCTUnwrap(context.fetch(descriptor).first)
    }
}
