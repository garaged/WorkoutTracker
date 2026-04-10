import XCTest

final class HeavyTrackedActivityPerformanceSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_heavyTrackedActivityLive_opensAndRemainsInteractive() {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_SEED"] = "1"
        app.launchEnvironment["UITESTS_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["UITESTS_START"] = "tracked-session-heavy"
        app.launchEnvironment["UITESTS_PERF_HEAVY_TRACKED_ACTIVITY"] = "1"
        app.launch()

        let liveScreen = app.descendants(matching: .any)["UITestHeavyTrackedSession.Screen"]
        XCTAssertTrue(liveScreen.waitForExistence(timeout: 5), "Expected heavy tracked-activity live route.")

        app.swipeUp()
        app.swipeDown()

        XCTAssertTrue(liveScreen.exists, "Expected heavy tracked-activity live route to remain visible after scrolling.")
        XCTAssertTrue(app.descendants(matching: .button).count > 0 || app.descendants(matching: .staticText).count > 0,
                      "Expected the heavy tracked-activity live route to render interactive content.")
    }

    func test_heavyTrackedActivitySummary_opensAndCanScroll() {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_SEED"] = "1"
        app.launchEnvironment["UITESTS_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["UITESTS_START"] = "tracked-summary-heavy"
        app.launchEnvironment["UITESTS_PERF_HEAVY_TRACKED_SUMMARY"] = "1"
        app.launch()

        let summaryScreen = app.descendants(matching: .any)["UITestHeavyTrackedSummary.Screen"]
        XCTAssertTrue(summaryScreen.waitForExistence(timeout: 5), "Expected heavy tracked-activity summary route.")

        app.swipeUp()
        app.swipeUp()
        app.swipeDown()

        XCTAssertTrue(summaryScreen.exists, "Expected heavy tracked-activity summary route to remain visible after scrolling.")
        XCTAssertTrue(app.descendants(matching: .staticText).count > 0,
                      "Expected heavy tracked-activity summary route to render summary text content.")
    }
}
