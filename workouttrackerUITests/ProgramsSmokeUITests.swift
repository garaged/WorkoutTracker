import XCTest

final class ProgramsSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_programLibrary_opensSeededProgram_andAllowsAssignment() {
        let app = UITestLaunch.app(
            start: "programs",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_PROGRAMS": "1"]
        )
        app.launch()

        XCTAssertTrue(app.navigationBars["Programs"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Seed Program V2"].waitForExistence(timeout: 8))

        app.staticTexts["Seed Program V2"].tap()

        XCTAssertTrue(app.buttons["programs.detail.assignButton"].waitForExistence(timeout: 8))
        app.buttons["programs.detail.assignButton"].tap()

        XCTAssertTrue(app.navigationBars["Assign Program"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Assign"].waitForExistence(timeout: 4))
        app.buttons["Assign"].tap()

        let openProgramProgress = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Open program progress"))
            .firstMatch
        XCTAssertTrue(openProgramProgress.waitForExistence(timeout: 8))
    }
}
