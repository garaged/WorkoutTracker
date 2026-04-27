import XCTest

final class ProgramAdherenceSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_programProgress_showsMissedState_whenSeeded() {
        let app = UITestLaunch.app(
            start: "program-progress",
            reset: true,
            seed: true,
            extraEnv: [
                "UITESTS_PROGRAMS": "1",
                "UITESTS_PROGRAMS_ASSIGNMENT": "1",
                "UITESTS_PROGRAMS_MISSED": "1"
            ]
        )
        app.launch()

        XCTAssertTrue(app.el("Programs.Progress.Screen").waitForExistence(timeout: 8))
        XCTAssertTrue(app.el("Programs.Progress.MissedCard").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Missed sessions"].waitForExistence(timeout: 4))
    }
}
