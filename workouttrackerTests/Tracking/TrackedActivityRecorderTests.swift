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
        session.updatedAt = start

        let totals = recorder.liveTotals(for: session, now: start.addingTimeInterval(30))
        XCTAssertEqual(totals.elapsedDuration, 120, accuracy: 0.001)
    }
}
