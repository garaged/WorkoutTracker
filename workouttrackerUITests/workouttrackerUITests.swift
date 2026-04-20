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

        openPlansFromHome(app, debugContext: "NavigateToTemplatesFromHomeTile")

        XCTAssertTrue(app.navigationBars["Plans"].waitForExistence(timeout: 6.0))

        let templatesCard = app.el("PlanningHub.Card.Templates")
        if !templatesCard.waitForExistence(timeout: 6.0) {
            attachUITestDebug(app, name: "NavigateToTemplatesFromHomeTile_TemplatesCardMissing")
        }
        XCTAssertTrue(templatesCard.exists)
        templatesCard.tap()

        XCTAssertTrue(app.navigationBars["Schedule Templates"].waitForExistence(timeout: 6.0))
    }

    func test_planningHub_templatesCard_hasStableAccessibilityIdentifier() {
        let app = UITestLaunch.app(start: "home", reset: true, seed: false)
        app.launch()

        openPlansFromHome(app, debugContext: "PlanningHubTemplatesCardIdentifier")

        XCTAssertTrue(app.navigationBars["Plans"].waitForExistence(timeout: 6.0))

        let templatesCard = app.el("PlanningHub.Card.Templates")
        if !templatesCard.waitForExistence(timeout: 6.0) {
            attachUITestDebug(app, name: "PlanningHubTemplatesCardIdentifier_TemplatesCardMissing")
        }
        XCTAssertTrue(templatesCard.exists, "Expected Templates card to remain discoverable by its accessibility identifier.")
    }

    private func openPlansFromHome(_ app: XCUIApplication, debugContext: String) {
        let plansTile = app.el("Home.Tile.Plans")
        if !plansTile.waitForExistence(timeout: 6.0) {
            attachUITestDebug(app, name: "\(debugContext)_PlansTileMissing")
        }
        XCTAssertTrue(plansTile.exists, "Expected Plans tile to remain discoverable by its accessibility identifier.")
        plansTile.tap()
    }
}
