import XCTest

final class workouttrackerUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func makeApp(start: String, resetDefaults: Bool, seed: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_START"] = start
        app.launchEnvironment["UITESTS_RESET"] = resetDefaults ? "1" : "0"
        app.launchEnvironment["UITESTS_SEED"] = seed ? "1" : "0"
        return app
    }

    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tapNewActivityButton(_ app: XCUIApplication, timeout: TimeInterval = 6.0) -> Bool {
        let byId = el(app, "timeline.newActivityButton")
        if byId.waitForExistence(timeout: timeout) {
            if byId.isHittable {
                byId.tap()
            } else {
                byId.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return true
        }

        // Fallback: look for an element labeled "New activity".
        let byLabel = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "New activity")).firstMatch
        if byLabel.waitForExistence(timeout: 2.0) {
            byLabel.tap()
            return true
        }

        return false
    }

    func test_createActivityFromPlusButton() {
        let app = makeApp(start: "calendar", resetDefaults: true, seed: false)
        app.launch()

        XCTAssertTrue(tapNewActivityButton(app), "Expected to find/tap New Activity button")

        XCTAssertTrue(app.navigationBars["New Activity"].waitForExistence(timeout: 4.0))

        let titleField = el(app, "activityEditor.titleField")
        XCTAssertTrue(titleField.waitForExistence(timeout: 4.0))
        titleField.tap()
        titleField.typeText("Test Activity")

        let save = el(app, "activityEditor.saveButton")
        XCTAssertTrue(save.waitForExistence(timeout: 2.0))
        save.tap()

        // Sheet should dismiss.
        XCTAssertFalse(app.navigationBars["New Activity"].waitForExistence(timeout: 1.0))
    }

    func test_navigateToTemplatesFromHomeTile() {
        let app = makeApp(start: "home", resetDefaults: true, seed: false)
        app.launch()

        // Home tiles are combined accessibility elements whose labels start with the title.
        let templatesTile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Templates"))
            .firstMatch

        XCTAssertTrue(templatesTile.waitForExistence(timeout: 6.0))
        templatesTile.tap()

        XCTAssertTrue(app.navigationBars["Templates"].waitForExistence(timeout: 6.0))
    }
}
