import XCTest
@testable import workouttracker

final class WatchPresentationEvaluatorTests: XCTestCase {
    private let evaluator = WatchPresentationEvaluator()

    func test_trackedControlsPrimaryAction_mapsPausedAndActiveStates() {
        XCTAssertEqual(evaluator.trackedControlsPrimaryAction(isPaused: true), .resume)
        XCTAssertEqual(evaluator.trackedControlsPrimaryAction(isPaused: false), .pause)
    }

    func test_footerStyle_prefersReconnectingForTrackedActivities() {
        XCTAssertEqual(
            evaluator.footerStyle(isTrackedActivitySession: true, isRecoveringRecentSession: true),
            .reconnecting
        )
        XCTAssertEqual(
            evaluator.footerStyle(isTrackedActivitySession: true, isRecoveringRecentSession: false),
            .currentActivity
        )
        XCTAssertEqual(
            evaluator.footerStyle(isTrackedActivitySession: false, isRecoveringRecentSession: false),
            .restTimer
        )
    }

    func test_currentActivityPrimaryActionTitle_changesForPausedState() {
        XCTAssertEqual(
            evaluator.currentActivityPrimaryActionTitle(isPaused: true),
            "Resume Activity"
        )
        XCTAssertEqual(
            evaluator.currentActivityPrimaryActionTitle(isPaused: false),
            "Open Current Activity"
        )
    }

    func test_currentActivityControlsActionTitle_changesForRecoveryState() {
        XCTAssertEqual(
            evaluator.currentActivityControlsActionTitle(isRecoveringRecentSession: true),
            "Reconnect Controls"
        )
        XCTAssertEqual(
            evaluator.currentActivityControlsActionTitle(isRecoveringRecentSession: false),
            "Open Controls"
        )
    }

    func test_trackedControlsPrimaryActionTitle_changesForPausedState() {
        XCTAssertEqual(evaluator.trackedControlsPrimaryActionTitle(isPaused: true), "Resume")
        XCTAssertEqual(evaluator.trackedControlsPrimaryActionTitle(isPaused: false), "Pause")
    }

    func test_footerText_matchesTrackedAndRecoveryStates() {
        XCTAssertEqual(
            evaluator.footerText(isTrackedActivitySession: true, isRecoveringRecentSession: true),
            "Controls stay here while the watch reconnects to your iPhone session."
        )
        XCTAssertEqual(
            evaluator.footerText(isTrackedActivitySession: true, isRecoveringRecentSession: false),
            "Use these controls to keep the current activity honest from your watch."
        )
        XCTAssertEqual(
            evaluator.footerText(isTrackedActivitySession: false, isRecoveringRecentSession: false),
            "Rest"
        )
    }
}
