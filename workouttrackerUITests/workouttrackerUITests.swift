import XCTest

final class workouttrackerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func makeApp(seed: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        if seed { app.launchEnvironment["UITESTS_SEED"] = "1" }
        return app
    }

    func test_createActivityFromPlusButton() {
        let app = makeApp(seed: true)
        app.launch()

        let add = app.buttons["nav.addActivity"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let title = app.textFields["activityEditor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("E2E — New Activity")

        let save = app.buttons["activityEditor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        save.tap()

        // The title should be visible back on the Day screen.
        XCTAssertTrue(app.staticTexts["E2E — New Activity"].waitForExistence(timeout: 5))
    }

    func test_navigateToTemplatesFromMenu() {
        let app = makeApp(seed: true)
        app.launch()

        let menu = app.buttons["nav.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()

        // Menu entries are exposed as buttons by their label text.
        let templates = app.buttons["Templates"]
        XCTAssertTrue(templates.waitForExistence(timeout: 5))
        templates.tap()

        XCTAssertTrue(app.navigationBars["Templates"].waitForExistence(timeout: 5))
    }
}
