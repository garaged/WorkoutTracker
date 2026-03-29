import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class IntentActionCoordinatorTests: XCTestCase {
    func test_openCurrentSession_blocksWhenNoSessionExists() throws {
        let context = try makeContext()
        let coordinator = IntentActionCoordinator()

        let result = try coordinator.openCurrentSession(context: context)

        XCTAssertEqual(result, .blocked(.noResumableSession))
    }

    func test_resumeCurrentSession_opensCanonicalSessionRoute() throws {
        let context = try makeContext()
        let session = WorkoutSession(startedAt: Date())
        session.status = .inProgress
        session.endedAt = nil
        context.insert(session)
        try context.save()

        let coordinator = IntentActionCoordinator()
        let result = try coordinator.resumeCurrentSession(context: context)

        XCTAssertEqual(result, .opened(.session(sessionID: session.id)))
    }

    func test_finishCurrentSession_marksSessionCompleted() throws {
        let context = try makeContext()
        let session = WorkoutSession(startedAt: Date())
        session.status = .inProgress
        session.endedAt = nil
        context.insert(session)
        try context.save()

        let coordinator = IntentActionCoordinator(now: { Date(timeIntervalSince1970: 1_234_567) })
        let result = try coordinator.finishCurrentSession(context: context)

        XCTAssertEqual(result, .opened(.home))
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.endedAt, Date(timeIntervalSince1970: 1_234_567))
    }

    func test_startRoutine_blocksWhenRoutineDoesNotExist() throws {
        let context = try makeContext()
        let coordinator = IntentActionCoordinator()

        let result = try coordinator.startRoutine(routineID: UUID(), context: context)

        XCTAssertEqual(result, .blocked(.routineNotFound))
    }

    func test_startRoutine_createsSessionForExistingRoutine() throws {
        let context = try makeContext()
        let routine = WorkoutRoutine(name: "Intent Routine", notes: nil)
        context.insert(routine)
        try context.save()

        let coordinator = IntentActionCoordinator(now: { Date(timeIntervalSince1970: 2_222_222) })
        let result = try coordinator.startRoutine(routineID: routine.id, context: context)

        guard case .opened(.session(let sessionID)) = result else {
            return XCTFail("Expected startRoutine to open the new session route.")
        }

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessionID, sessions[0].id)
        XCTAssertEqual(sessions[0].sourceRoutineId, routine.id)
        XCTAssertEqual(sessions[0].sourceRoutineNameSnapshot, routine.name)
        XCTAssertEqual(sessions[0].startedAt, Date(timeIntervalSince1970: 2_222_222))
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return ModelContext(container)
    }
}
