import XCTest

final class Phase5HistoryCompareSmokeUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_workoutsScreen_opens_andShowsListOrEmptyState() {
        let app = UITestLaunch.app(start: "home", reset: true, seed: true) // seed optional; test accepts empty too
        app.launch()

        // Home tile is "Workouts", not "History"
        let workoutsTile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Workouts"))
            .firstMatch

        XCTAssertTrue(workoutsTile.waitForExistence(timeout: 8), "Expected Home Workouts tile.")
        workoutsTile.tap()

        // Accept common titles
        let workoutsNav = app.navigationBars["Workouts"]
        let sessionsNav = app.navigationBars["Sessions"]
        XCTAssertTrue(
            workoutsNav.waitForExistence(timeout: 6) || sessionsNav.waitForExistence(timeout: 6),
            "Expected to navigate into Workouts/Sessions screen."
        )

        // Pass if we have any sessions OR an empty-state message
        let hasCells = app.tables.cells.count > 0 || app.collectionViews.cells.count > 0
        let hasEmpty = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "No")).firstMatch.exists

        XCTAssertTrue(hasCells || hasEmpty, "Expected session list or an empty state.")
    }
}
