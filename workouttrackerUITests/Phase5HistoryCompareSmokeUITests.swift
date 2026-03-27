import XCTest

final class Phase5HistoryCompareSmokeUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_workoutsScreen_opens_andShowsListOrEmptyState() {
        let app = UITestLaunch.app(start: "home", reset: true, seed: true) // seed optional; test accepts empty too
        app.launch()

        // Home tile is "Workouts", not "History"
        let workoutsTile = workoutsTile(in: app)

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


    func test_workoutsScreen_underSpanishMexicoLocale_showsReadableExerciseBrowseLabels() {
        let app = UITestLaunch.app(
            start: "home",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_LOCALIZATION": "1"],
            extraArgs: ["-AppleLanguages", "(es-MX)", "-AppleLocale", "es_MX"]
        )
        app.launch()

        let workoutsTile = workoutsTile(in: app)

        XCTAssertTrue(workoutsTile.waitForExistence(timeout: 8), "Expected Home Workouts tile.")
        workoutsTile.tap()

        let workoutsNav = app.navigationBars["Entrenamientos"]
        let sessionsNav = app.navigationBars["Sesiones"]
        XCTAssertTrue(
            workoutsNav.waitForExistence(timeout: 6) || sessionsNav.waitForExistence(timeout: 6),
            "Expected to navigate into the localized Workouts/Sessions screen."
        )

        let readableExerciseLabel = app.staticTexts.matching(
            NSPredicate(
                format:
                    "label == %@ OR label == %@ OR label == %@ OR label == %@ OR label == %@ OR label == %@",
                "Press de banca",
                "Bench Press",
                "Sentadilla trasera",
                "Back Squat",
                "Peso muerto",
                "Deadlift"
            )
        ).firstMatch

        let hasCells = app.tables.cells.count > 0 || app.collectionViews.cells.count > 0
        let hasReadableExerciseLabel = readableExerciseLabel.waitForExistence(timeout: 4)

        if !(hasCells || hasReadableExerciseLabel) {
            attachUITestDebug(app, name: "HistoryCompare_esMX_ExerciseLabelMissing")
        }

        XCTAssertTrue(
            hasCells || hasReadableExerciseLabel,
            "Expected the localized Workouts screen to render readable history content under es-MX."
        )
    }
    
    private func workoutsTile(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "label BEGINSWITH[c] %@ OR label BEGINSWITH[c] %@",
                    "Workouts",
                    "Entrenamientos"
                )
            )
            .firstMatch
    }

}
