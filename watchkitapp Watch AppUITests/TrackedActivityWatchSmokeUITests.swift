import XCTest

final class TrackedActivityWatchSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_seededPausedTrackedActivity_opensControlsAndShowsResume() {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["WATCH_UITESTS"] = "1"
        app.launchEnvironment["WATCH_UITEST_ROUTE"] = "shortcuts"
        app.launchEnvironment["WATCH_UITEST_STATE"] = "trackedPaused"
        app.launchEnvironment["WATCH_UITEST_CAN_SEND_COMMANDS"] = "1"
        app.launchEnvironment["WATCH_UITEST_IS_REACHABLE"] = "1"
        app.launch()

        let shortcutsScreen = app.descendants(matching: .any)["Watch.Shortcuts.Screen"]
        XCTAssertTrue(shortcutsScreen.waitForExistence(timeout: 5), "Expected watch shortcuts screen.")

        let trackedStatus = app.descendants(matching: .any)["Watch.Shortcuts.TrackedStatus"]
        XCTAssertTrue(
            trackedStatus.waitForExistence(timeout: 3) ||
            app.staticTexts["Paused"].waitForExistence(timeout: 3) ||
            app.staticTexts["Paused — reconnecting"].waitForExistence(timeout: 3),
            "Expected paused tracked-activity status."
        )

        let openControls = app.descendants(matching: .any)["Watch.Shortcuts.OpenCurrentActivity"]
        XCTAssertTrue(openControls.waitForExistence(timeout: 3), "Expected current activity controls entry point.")
        tapSafely(openControls)

        let nowPlayingScreen = app.descendants(matching: .any)["Watch.NowPlaying.Screen"]
        XCTAssertTrue(nowPlayingScreen.waitForExistence(timeout: 5), "Expected now playing controls screen.")

        let trackedStatusOnControls = app.descendants(matching: .any)["Watch.NowPlaying.TrackedStatus"]
        XCTAssertTrue(
            trackedStatusOnControls.waitForExistence(timeout: 3) ||
            app.staticTexts["Paused"].waitForExistence(timeout: 3) ||
            app.staticTexts["Paused — reconnecting"].waitForExistence(timeout: 3),
            "Expected tracked-activity status on controls screen."
        )

        let resumePredicate = NSPredicate(format: "label CONTAINS[c] %@", "Resume")
        let resumeButton = app.buttons.matching(resumePredicate).firstMatch

        if !resumeButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        if !resumeButton.exists {
            app.swipeUp()
        }

        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5), "Expected Resume control for paused tracked activity.")
        XCTAssertTrue(resumeButton.isHittable || resumeButton.exists, "Expected Resume control to be present after opening controls.")
    }

    private func tapSafely(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
