import XCTest
@testable import workouttracker

@MainActor
final class TrackedActivityRecorderTests: XCTestCase {
    private let recorder = TrackedActivityRecorder()

    func testPauseResumeAndComplete_accumulatesElapsedDurationAcrossTransitions() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = TrackedActivitySession(activityKind: .walking)

        session.start(at: start)
        session.pause(at: start.addingTimeInterval(125))
        session.resume(at: start.addingTimeInterval(200))
        session.complete(at: start.addingTimeInterval(320))

        XCTAssertEqual(session.lifecycleState, .completed)
        XCTAssertEqual(session.elapsedDuration, 245, accuracy: 0.001)
    }

    func testLiveTotals_runningSessionAddsElapsedTimeSinceLastResume() {
        let start = Date(timeIntervalSince1970: 2_000)
        let session = TrackedActivitySession(
            activityKind: .running,
            lifecycleState: .inProgress,
            totals: TrackedActivityTotals(elapsedDuration: 90)
        )
        session.startedAt = start
        session.activeIntervalStartedAt = start
        session.updatedAt = start.addingTimeInterval(999)

        let totals = recorder.liveTotals(for: session, now: start.addingTimeInterval(30))
        XCTAssertEqual(totals.elapsedDuration, 120, accuracy: 0.001)
    }
    func testMarkBackgroundedAndKeepForLater_updateRecoveryMetadata() {
        let start = Date(timeIntervalSince1970: 4_000)
        let session = TrackedActivitySession(
            createdAt: start,
            updatedAt: start,
            startedAt: start,
            endedAt: nil,
            activeIntervalStartedAt: start,
            activityKind: .walking,
            environment: .outdoor,
            lifecycleState: .inProgress,
            totals: TrackedActivityTotals(elapsedDuration: 0),
            lastResumedAt: start
        )

        session.markBackgrounded(at: start.addingTimeInterval(20))
        session.keepForLater(at: start.addingTimeInterval(30))

        XCTAssertEqual(session.lastBackgroundedAt, start.addingTimeInterval(20))
        XCTAssertEqual(session.dismissedRecoveryPromptAt, start.addingTimeInterval(30))

        session.resume(at: start.addingTimeInterval(40))
        XCTAssertEqual(session.lastResumedAt, start.addingTimeInterval(40))
        XCTAssertNil(session.dismissedRecoveryPromptAt)
    }

}
