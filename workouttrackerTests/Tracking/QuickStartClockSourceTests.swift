import XCTest
@testable import workouttracker

final class QuickStartClockSourceTests: XCTestCase {
    func testInjectedSourceUsesWallAndContinuousDurationWithStableEpoch() {
        let epoch = UUID()
        var wall = Date(timeIntervalSince1970: 1_000)
        var elapsed = Duration.seconds(12) + .milliseconds(250)
        let source = QuickStartClockSource(
            wallNow: { wall },
            elapsedNow: { elapsed },
            epoch: epoch
        )

        let first = source.sample()
        XCTAssertEqual(first.wall, wall)
        XCTAssertEqual(first.uptime, 12.25, accuracy: 0.000_001)
        XCTAssertEqual(first.epoch, epoch)

        wall = Date(timeIntervalSince1970: 1_007.5)
        elapsed += .milliseconds(7_500)
        let second = source.sample()
        XCTAssertEqual(second.wall, wall)
        XCTAssertEqual(second.uptime, 19.75, accuracy: 0.000_001)
        XCTAssertEqual(second.epoch, epoch)
    }

    func testInjectedSourceClampsImpossibleNegativeElapsedValue() {
        let source = QuickStartClockSource(
            wallNow: { Date(timeIntervalSince1970: 500) },
            elapsedNow: { .milliseconds(-1) },
            epoch: UUID()
        )

        XCTAssertEqual(source.sample().uptime, 0)
    }

    func testSamplesDriveReducerWithoutDisplayTickAccumulation() throws {
        let epoch = UUID()
        var wall = Date(timeIntervalSince1970: 2_000)
        var elapsed = Duration.zero
        let source = QuickStartClockSource(
            wallNow: { wall },
            elapsedNow: { elapsed },
            epoch: epoch
        )
        var state = try QuickStartTimingState().applying(
            .start,
            id: UUID(),
            expectedRevision: 0,
            at: source.sample()
        )

        wall.addTimeInterval(37)
        elapsed += .seconds(37)
        state = try state.applying(
            .finish,
            id: UUID(),
            expectedRevision: state.revision,
            at: source.sample()
        )

        XCTAssertEqual(state.accumulated, 37, accuracy: 0.000_001)
    }

    func testProductionSourceMaintainsEpochAndNondecreasingUptime() {
        let source = QuickStartClockSource()
        let first = source.sample()
        let second = source.sample()

        XCTAssertEqual(second.epoch, first.epoch)
        XCTAssertGreaterThanOrEqual(second.uptime, first.uptime)
        XCTAssertGreaterThan(first.wall.timeIntervalSince1970, 0)
    }
}
