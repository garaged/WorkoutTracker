import XCTest
@testable import workouttracker

final class TrackedActivitySummaryTests: XCTestCase {

    func testYogaSummary_doesNotSurfaceDistanceOrPaceMetrics() {
        let summary = TrackedActivitySummary(
            sessionID: UUID(),
            activityKind: .yoga,
            environment: .indoor,
            lifecycleState: .completed,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 1_000),
            totals: TrackedActivityTotals(
                elapsedDuration: 900,
                distanceMeters: nil,
                activeEnergyKilocalories: 140,
                stepCount: nil
            ),
            healthKitExportState: .notRequested
        )

        XCTAssertEqual(summary.highlightedMetricKinds, [.duration, .activeEnergy])
        XCTAssertNil(summary.averagePaceSecondsPerKilometer)
    }

    func testRunningSummary_withoutDistanceDoesNotFabricatePace() {
        let summary = TrackedActivitySummary(
            sessionID: UUID(),
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .completed,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 1_000),
            totals: TrackedActivityTotals(
                elapsedDuration: 900,
                distanceMeters: nil,
                activeEnergyKilocalories: nil,
                stepCount: nil
            ),
            healthKitExportState: .notRequested
        )

        XCTAssertEqual(summary.highlightedMetricKinds, [.duration])
        XCTAssertNil(summary.averagePaceSecondsPerKilometer)
    }
}
