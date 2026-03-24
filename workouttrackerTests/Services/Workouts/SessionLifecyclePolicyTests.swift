import XCTest
@testable import workouttracker

final class SessionLifecyclePolicyTests: XCTestCase {
    private let policy = SessionLifecyclePolicy()

    func test_inProgressNotPaused_canMutate() {
        let session = WorkoutSession()
        session.status = .inProgress
        session.isPaused = false

        XCTAssertTrue(policy.canMutateProgress(session))
    }

    func test_inProgressPaused_cannotMutate() {
        let session = WorkoutSession()
        session.status = .inProgress
        session.isPaused = true

        XCTAssertFalse(policy.canMutateProgress(session))
    }

    func test_completed_cannotMutate() {
        let session = WorkoutSession()
        session.status = .completed

        XCTAssertFalse(policy.canMutateProgress(session))
    }

    func test_abandoned_cannotMutate() {
        let session = WorkoutSession()
        session.status = .abandoned

        XCTAssertFalse(policy.canMutateProgress(session))
    }
}
