import XCTest
@testable import workouttracker

final class TrackedActivitySummaryCardTests: XCTestCase {
    func test_build_omitsPaceForYogaAndIncludesRecentSessions() {
        let yoga = TrackedActivitySummary(
            sessionID: UUID(),
            activityKind: .yoga,
            environment: .indoor,
            lifecycleState: .completed,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 400),
            totals: TrackedActivityTotals(elapsedDuration: 300, distanceMeters: nil, activeEnergyKilocalories: 120, stepCount: nil),
            healthKitExportState: .notRequested
        )

        let model = TrackedActivitySummaryCardModel.build(from: [yoga])

        XCTAssertNotNil(model)
        XCTAssertEqual(model?.recentSessions.count, 1)
        XCTAssertFalse(model?.recentSessions.first?.detail.contains("/km") ?? true)
    }
}
