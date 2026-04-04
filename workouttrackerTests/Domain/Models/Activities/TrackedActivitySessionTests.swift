import XCTest
@testable import workouttracker

final class TrackedActivitySessionTests: XCTestCase {

    func testInit_clampsNegativeElapsedDurationToZero() {
        let session = TrackedActivitySession(
            activityKind: .walking,
            totals: TrackedActivityTotals(elapsedDuration: -45, distanceMeters: 100)
        )

        XCTAssertEqual(session.elapsedDuration, 0)
        XCTAssertEqual(session.totals.elapsedDuration, 0)
    }

    func testYogaSession_canExistWithoutDistance() {
        let session = TrackedActivitySession(
            activityKind: .yoga,
            totals: TrackedActivityTotals(elapsedDuration: 1_800)
        )

        XCTAssertNil(session.distanceMeters)
        XCTAssertEqual(session.activityKind, .yoga)
        XCTAssertEqual(session.summary.highlightedMetricKinds, [.duration])
    }

    func testCompletedSession_withoutEndedAt_normalizesEndedAt() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000)
        let session = TrackedActivitySession(
            startedAt: startedAt,
            activityKind: .running,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: 900, distanceMeters: 5_000)
        )

        XCTAssertNotNil(session.endedAt)
        XCTAssertEqual(session.lifecycleState, .completed)
    }

    func testRawValueWrappers_roundTripCorrectly() {
        let session = TrackedActivitySession(activityKind: .walking)

        session.activityKind = .hiking
        session.environment = .outdoor
        session.lifecycleState = .paused
        session.healthKitExportState = .pending

        XCTAssertEqual(session.activityKindRaw, TrackedActivityKind.hiking.rawValue)
        XCTAssertEqual(session.environmentRaw, ActivityEnvironment.outdoor.rawValue)
        XCTAssertEqual(session.lifecycleStateRaw, TrackedActivityLifecycleState.paused.rawValue)
        XCTAssertEqual(session.healthKitExportStateRaw, HealthKitExportState.pending.rawValue)
    }

    func testSummary_runningWithDistanceIncludesDistanceAndPaceHighlights() throws {
        let session = TrackedActivitySession(
            activityKind: .running,
            totals: TrackedActivityTotals(
                elapsedDuration: 1_500,
                distanceMeters: 5_000,
                activeEnergyKilocalories: 320,
                stepCount: 6_100
            )
        )

        XCTAssertEqual(
            session.summary.highlightedMetricKinds,
            [.duration, .distance, .averagePace, .activeEnergy, .stepCount]
        )

        let averagePace = try XCTUnwrap(session.summary.averagePaceSecondsPerKilometer)
        XCTAssertEqual(averagePace, 300, accuracy: 0.001)
    }
}
