import XCTest

final class TrackedActivityWatchPerformanceUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_seededPausedTrackedActivity_controlsRemainReachableAfterRepeatedScrolls() {
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

        let openControls = app.descendants(matching: .any)["Watch.Shortcuts.OpenCurrentActivity"]
        XCTAssertTrue(openControls.waitForExistence(timeout: 3), "Expected current activity controls entry point.")
        tapSafely(openControls)

        let nowPlayingScreen = app.descendants(matching: .any)["Watch.NowPlaying.Screen"]
        XCTAssertTrue(nowPlayingScreen.waitForExistence(timeout: 5), "Expected now playing controls screen.")

        let resumePredicate = NSPredicate(format: "label CONTAINS[c] %@", "Resume")
        let resumeButton = app.buttons.matching(resumePredicate).firstMatch
        XCTAssertTrue(ensureResumeVisible(resumeButton, in: app), "Expected Resume control for paused tracked activity.")

        app.swipeUp()
        app.swipeDown()
        app.swipeUp()

        XCTAssertTrue(ensureResumeVisible(resumeButton, in: app), "Expected Resume control to remain reachable after repeated scrolls.")
    }

    private func ensureResumeVisible(_ resumeButton: XCUIElement, in app: XCUIApplication) -> Bool {
        if resumeButton.waitForExistence(timeout: 2), resumeButton.isHittable || resumeButton.exists {
            return true
        }

        for _ in 0..<3 {
            app.swipeUp()
            if resumeButton.waitForExistence(timeout: 1), resumeButton.isHittable || resumeButton.exists {
                return true
            }
        }

        for _ in 0..<3 {
            app.swipeDown()
            if resumeButton.waitForExistence(timeout: 1), resumeButton.isHittable || resumeButton.exists {
                return true
            }
        }

        return resumeButton.exists
    }

    private func tapSafely(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
