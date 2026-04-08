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
        XCTAssertEqual(model?.stats.first?.title, "Total time")
    }

    func test_build_includesDistanceMixAndLowDataMessageForPartialDistanceCoverage() {
        let run = TrackedActivitySummary(
            sessionID: UUID(),
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .completed,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 700),
            totals: TrackedActivityTotals(elapsedDuration: 600, distanceMeters: 4200, activeEnergyKilocalories: 320, stepCount: 5200),
            healthKitExportState: .exported
        )

        let walkWithoutDistance = TrackedActivitySummary(
            sessionID: UUID(),
            activityKind: .walking,
            environment: .outdoor,
            lifecycleState: .completed,
            startedAt: Date(timeIntervalSince1970: 800),
            endedAt: Date(timeIntervalSince1970: 1400),
            totals: TrackedActivityTotals(elapsedDuration: 600, distanceMeters: nil, activeEnergyKilocalories: 180, stepCount: 3100),
            healthKitExportState: .notRequested
        )

        let model = TrackedActivitySummaryCardModel.build(from: [run, walkWithoutDistance])

        XCTAssertNotNil(model)
        XCTAssertEqual(model?.activityMix.count, 2)
        XCTAssertTrue(model?.supportingText.contains("tracked activities") ?? false)
        XCTAssertNotNil(model?.lowDataMessage)
        XCTAssertTrue(model?.stats.contains(where: { $0.title == "Distance" }) ?? false)
    }
}
