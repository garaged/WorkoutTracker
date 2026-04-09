import XCTest
@testable import workouttracker

final class WatchRouteLaunchStateMachineTests: XCTestCase {
    func test_armThenConsumeAutoOpen_opensNowPlayingWhenSessionBecomesAvailable() {
        var machine = WatchRouteLaunchStateMachine()
        machine.armAutoOpenControls()

        machine.consumeAutoOpenIfPossible(hasActiveSession: true)

        XCTAssertEqual(machine.route, .nowPlaying)
        XCTAssertFalse(machine.shouldAutoOpenControls)
    }

    func test_consumeAutoOpen_doesNothingWithoutSession() {
        var machine = WatchRouteLaunchStateMachine()
        machine.armAutoOpenControls()

        machine.consumeAutoOpenIfPossible(hasActiveSession: false)

        XCTAssertEqual(machine.route, .shortcuts)
        XCTAssertTrue(machine.shouldAutoOpenControls)
    }

    func test_showShortcuts_clearsAutoOpenIntent() {
        var machine = WatchRouteLaunchStateMachine()
        machine.armAutoOpenControls()
        machine.openNowPlaying()

        machine.showShortcuts()

        XCTAssertEqual(machine.route, .shortcuts)
        XCTAssertFalse(machine.shouldAutoOpenControls)
    }

    func test_openNowPlaying_clearsAutoOpenIntent() {
        var machine = WatchRouteLaunchStateMachine()
        machine.armAutoOpenControls()

        machine.openNowPlaying()

        XCTAssertEqual(machine.route, .nowPlaying)
        XCTAssertFalse(machine.shouldAutoOpenControls)
    }
}
