import XCTest
@testable import workouttracker

final class WatchRecoveryEvaluatorTests: XCTestCase {
    private let evaluator = WatchRecoveryEvaluator(recoveryGraceInterval: 20)

    func test_isRecoveringRecentSession_trueWhenTransportUnhealthyAndWithinGrace() {
        let now = Date(timeIntervalSince1970: 1_000)
        let lastReceived = now.addingTimeInterval(-8)

        XCTAssertTrue(
            evaluator.isRecoveringRecentSession(
                sourceIsActiveSession: false,
                canSendCommands: false,
                isReachable: false,
                lastKnownActiveSession: true,
                lastStateReceivedAt: lastReceived,
                now: now
            )
        )
    }

    func test_isRecoveringRecentSession_falseWhenTransportHealthy() {
        let now = Date(timeIntervalSince1970: 1_000)
        let lastReceived = now.addingTimeInterval(-8)

        XCTAssertFalse(
            evaluator.isRecoveringRecentSession(
                sourceIsActiveSession: false,
                canSendCommands: true,
                isReachable: true,
                lastKnownActiveSession: true,
                lastStateReceivedAt: lastReceived,
                now: now
            )
        )
    }

    func test_isRecoveringRecentSession_falseWhenOutsideGraceWindow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let lastReceived = now.addingTimeInterval(-25)

        XCTAssertFalse(
            evaluator.isRecoveringRecentSession(
                sourceIsActiveSession: false,
                canSendCommands: false,
                isReachable: false,
                lastKnownActiveSession: true,
                lastStateReceivedAt: lastReceived,
                now: now
            )
        )
    }

    func test_transportStatus_prioritizesReconnecting() {
        XCTAssertEqual(
            evaluator.transportStatus(
                isRecoveringRecentSession: true,
                canSendCommands: false,
                isReachable: false
            ),
            .reconnecting
        )
    }

    func test_shouldRunLocalTicker_trueForTrackedActivityElapsedBaseline() {
        let now = Date(timeIntervalSince1970: 2_000)
        let source = WatchRecoveryEvaluator.SourceState(
            isActiveSession: true,
            isTrackedActivitySession: true,
            isPaused: false,
            isRestRunning: false,
            restEndsAtEpochSeconds: nil,
            elapsedSeconds: 120,
            elapsedUpdatedAtEpochSeconds: now.timeIntervalSince1970 - 5
        )

        XCTAssertTrue(
            evaluator.shouldRunLocalTicker(
                for: source,
                isRecoveringRecentSession: false,
                now: now
            )
        )
    }

    func test_shouldRunLocalTicker_trueDuringRecoveryEvenWhenSourceInactive() {
        let now = Date(timeIntervalSince1970: 2_000)
        let source = WatchRecoveryEvaluator.SourceState()

        XCTAssertTrue(
            evaluator.shouldRunLocalTicker(
                for: source,
                isRecoveringRecentSession: true,
                now: now
            )
        )
    }

    func test_trackedActivityStatus_mapsPausedAndRecoveryStates() {
        XCTAssertEqual(
            evaluator.trackedActivityStatus(isPaused: true, isRecoveringRecentSession: false),
            .paused
        )
        XCTAssertEqual(
            evaluator.trackedActivityStatus(isPaused: true, isRecoveringRecentSession: true),
            .pausedReconnecting
        )
        XCTAssertEqual(
            evaluator.trackedActivityStatus(isPaused: false, isRecoveringRecentSession: true),
            .liveReconnecting
        )
        XCTAssertEqual(
            evaluator.trackedActivityStatus(isPaused: false, isRecoveringRecentSession: false),
            .trackingLiveOnPhone
        )
    }
}
