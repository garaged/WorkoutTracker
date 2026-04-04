import XCTest
@testable import workouttracker

final class TrackedActivitySummaryBuilderTests: XCTestCase {
    private let builder = TrackedActivitySummaryBuilder()

    func testMetrics_runningIncludesPaceWhenDistanceExists() {
        let session = TrackedActivitySession(
            activityKind: .running,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(
                elapsedDuration: 1_500,
                distanceMeters: 5_000,
                activeEnergyKilocalories: 320,
                stepCount: 6_100
            )
        )

        let metricKinds = builder.metrics(for: session.summary).map(\.kind)
        XCTAssertTrue(metricKinds.contains(.averagePace))
        XCTAssertTrue(metricKinds.contains(.distance))
    }

    func testMetrics_yogaStaysDurationCentric() {
        let session = TrackedActivitySession(
            activityKind: .yoga,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: 2_400)
        )

        let metricKinds = builder.metrics(for: session.summary).map(\.kind)
        XCTAssertEqual(metricKinds, [.duration, .state])
    }
}
