import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class IntentPreconditionEvaluatorTests: XCTestCase {
    func test_resumableSession_blocksWhenNoInProgressSession() {
        let evaluator = IntentPreconditionEvaluator()

        let result = evaluator.resumableSession(from: [], activitiesByID: [:])

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual(result.failure, .noResumableSession)
    }

    func test_finishableSession_allowsInProgressUnfinishedSession() {
        let evaluator = IntentPreconditionEvaluator()
        let session = WorkoutSession(startedAt: Date())
        session.status = .inProgress
        session.endedAt = nil

        let result = evaluator.finishableSession(from: [session], activitiesByID: [:])

        XCTAssertTrue(result.isAllowed)
        XCTAssertEqual(result.value?.id, session.id)
    }

    func test_restCapableSession_blocksWhenNoContextExists() {
        let evaluator = IntentPreconditionEvaluator()

        let result = evaluator.restCapableSession(from: [], activitiesByID: [:], hasConfiguredRestTimer: false)

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual(result.failure, .noRestCapableContext)
    }

    func test_restCapableSession_allowsActiveSessionWhenRestTimerAlreadyConfigured() {
        let evaluator = IntentPreconditionEvaluator()
        let session = WorkoutSession(startedAt: Date())
        session.status = .inProgress
        session.endedAt = nil

        let result = evaluator.restCapableSession(from: [session], activitiesByID: [:], hasConfiguredRestTimer: true)

        XCTAssertTrue(result.isAllowed)
        XCTAssertEqual(result.value?.id, session.id)
    }
}
