import XCTest

final class ProgramProgressionSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_programProgress_showsWeekAndNextRecommendedAction() {
        let app = UITestLaunch.app(
            start: "program-progress",
            reset: true,
            seed: true,
            extraEnv: [
                "UITESTS_PROGRAMS": "1",
                "UITESTS_PROGRAMS_ASSIGNMENT": "1"
            ]
        )
        app.launch()

        XCTAssertTrue(app.el("Programs.Progress.Screen").waitForExistence(timeout: 8))
        XCTAssertTrue(app.el("Programs.Progress.NextAction").waitForExistence(timeout: 8))
        XCTAssertTrue(app.el("Programs.Progress.CurrentWeek").waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Open in Calendar"].waitForExistence(timeout: 8))
    }
}
