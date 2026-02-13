// File: workouttrackerUITests/workouttrackerUITests.swift
import XCTest

final class workouttrackerUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_createActivityFromPlusButton() {
        let app = UITestLaunch.app(start: "calendar", reset: true, seed: false)
        app.launch()

        XCTAssertTrue(tapNewActivityButton(app), "Expected to find/tap New Activity button")

        XCTAssertTrue(app.navigationBars["New Activity"].waitForExistence(timeout: 4.0))

        let titleField = app.el("activityEditor.titleField")
        XCTAssertTrue(titleField.waitForExistence(timeout: 4.0))
        titleField.tap()
        titleField.typeText("Test Activity")

        let save = app.el("activityEditor.saveButton")
        XCTAssertTrue(save.waitForExistence(timeout: 2.0))
        save.tap()

        XCTAssertFalse(app.navigationBars["New Activity"].waitForExistence(timeout: 1.0))
    }

    func test_navigateToTemplatesFromHomeTile() {
        let app = UITestLaunch.app(start: "home", reset: true, seed: false)
        app.launch()

        let templatesTile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Templates"))
            .firstMatch

        XCTAssertTrue(templatesTile.waitForExistence(timeout: 6.0))
        templatesTile.tap()

        XCTAssertTrue(app.navigationBars["Templates"].waitForExistence(timeout: 6.0))
    }
}
