import XCTest
@testable import workouttracker

final class TrackedActivitySessionTimingTests: XCTestCase {

    func test_liveElapsedDuration_ignoresUpdatedAtTouchesWhileInProgress() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let session = TrackedActivitySession(
            createdAt: start,
            updatedAt: start,
            startedAt: start,
            endedAt: nil,
            activeIntervalStartedAt: start,
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .inProgress,
            totals: TrackedActivityTotals(elapsedDuration: 0)
        )

        session.updatedAt = start.addingTimeInterval(45)

        XCTAssertEqual(session.liveElapsedDuration(at: start.addingTimeInterval(90)), 90, accuracy: 0.001)
    }

    func test_pauseAndResume_accumulatesElapsedAcrossIntervals() {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        let session = TrackedActivitySession(
            createdAt: start,
            updatedAt: start,
            startedAt: start,
            endedAt: nil,
            activeIntervalStartedAt: start,
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .inProgress,
            totals: TrackedActivityTotals(elapsedDuration: 0)
        )

        session.pause(at: start.addingTimeInterval(40))
        XCTAssertEqual(session.elapsedDuration, 40, accuracy: 0.001)
        XCTAssertNil(session.activeIntervalStartedAt)

        session.resume(at: start.addingTimeInterval(100))
        XCTAssertEqual(session.liveElapsedDuration(at: start.addingTimeInterval(130)), 70, accuracy: 0.001)

        session.complete(at: start.addingTimeInterval(140))
        XCTAssertEqual(session.elapsedDuration, 80, accuracy: 0.001)
        XCTAssertEqual(session.lifecycleState, .completed)
    }

    func test_markLocalChangesSinceExport_onlyFlagsWhenAlreadyExported() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        let session = TrackedActivitySession(
            createdAt: start,
            updatedAt: start,
            startedAt: start,
            endedAt: start.addingTimeInterval(60),
            activeIntervalStartedAt: nil,
            activityKind: .walking,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: 60),
            healthKitExportState: .notRequested
        )

        session.markLocalChangesSinceHealthKitExport(at: start.addingTimeInterval(70))
        XCTAssertFalse(session.hasLocalChangesSinceHealthKitExport)

        session.markHealthKitExportSucceeded(at: start.addingTimeInterval(80))
        session.markLocalChangesSinceHealthKitExport(at: start.addingTimeInterval(90))
        XCTAssertTrue(session.hasLocalChangesSinceHealthKitExport)
    }
}
