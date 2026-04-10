import XCTest

final class HeavySessionPerformanceSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_heavySeededSession_opensAndCanScrollToLaterContent() {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_SEED"] = "1"
        app.launchEnvironment["UITESTS_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["UITESTS_START"] = "session-heavy"
        app.launchEnvironment["UITESTS_PERF_HEAVY_SESSION"] = "1"
        app.launch()

        let sessionScreen = app.descendants(matching: .any)["WorkoutSession.Screen"]
        XCTAssertTrue(sessionScreen.waitForExistence(timeout: 5), "Expected heavy seeded workout session screen.")

        let actionableRow = app.descendants(matching: .any)["WorkoutSession.ActionableSetRow"]
        XCTAssertTrue(actionableRow.waitForExistence(timeout: 5), "Expected an actionable set row in the heavy seeded session.")

        let laterExercise = app.staticTexts["UITest Heavy Exercise 08"]
        XCTAssertTrue(
            scrollUntilVisible(laterExercise, in: sessionScreen, maxSwipes: 8, direction: .up),
            "Expected to reach later heavy-session content after scrolling."
        )

        let earlierExercise = app.staticTexts["UITest Heavy Exercise 02"]
        XCTAssertTrue(
            scrollUntilVisible(earlierExercise, in: sessionScreen, maxSwipes: 8, direction: .down),
            "Expected to return toward earlier heavy-session content after scrolling back."
        )
    }

    private enum ScrollDirection {
        case up
        case down
    }

    @discardableResult
    private func scrollUntilVisible(
        _ element: XCUIElement,
        in container: XCUIElement,
        maxSwipes: Int,
        direction: ScrollDirection
    ) -> Bool {
        if element.waitForExistence(timeout: 1) { return true }

        for _ in 0..<maxSwipes {
            switch direction {
            case .up:
                if container.exists {
                    container.swipeUp()
                } else {
                    XCUIApplication().swipeUp()
                }
            case .down:
                if container.exists {
                    container.swipeDown()
                } else {
                    XCUIApplication().swipeDown()
                }
            }

            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return element.exists
    }
}
