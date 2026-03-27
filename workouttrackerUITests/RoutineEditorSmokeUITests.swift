// File: workouttrackerUITests/RoutineEditorSmokeUITests.swift
import XCTest

final class RoutineEditorSmokeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_createRoutine_cancelImmediately_doesNotLeaveExtraRoutineRow() {
        app = UITestLaunch.app(start: "routines", reset: true, seed: true)
        app.launch()

        let createButton = createRoutineButton(in: app)
        XCTAssertTrue(createButton.waitForExistence(timeout: t(8)), "Expected Routines screen")

        let beforeCount = waitForStableRoutineRowCount(in: app, minimum: 1, timeout: t(8))
        XCTAssertGreaterThan(beforeCount, 0, "Expected at least one seeded routine row before opening create")

        tapSafely(createButton)

        XCTAssertTrue(newRoutineNavigationBar(in: app).waitForExistence(timeout: t(6)), "Expected New Routine editor")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: t(4)), "Expected Cancel button in New Routine editor")
        tapSafely(cancelButton)

        XCTAssertTrue(createButton.waitForExistence(timeout: t(6)), "Expected to return to Routines screen after cancel")

        let afterCount = waitForStableRoutineRowCount(in: app, minimum: 1, timeout: t(8))

        if afterCount != beforeCount {
            attachUITestDebug(app, name: "RoutineCreateCancel_RowCountChanged")
        }

        XCTAssertEqual(
            afterCount,
            beforeCount,
            "Canceling routine creation should not leave an extra blank/orphan routine row"
        )
    }

    func test_seededRoutine_showsLocalizedBuiltInExercise_underSpanishMexicoLocale() {
        app = UITestLaunch.app(
            start: "routines",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_LOCALIZATION": "1"],
            extraArgs: ["-AppleLanguages", "(es-MX)", "-AppleLocale", "es_MX"]
        )
        app.launch()

        let createButton = createRoutineButton(in: app)
        XCTAssertTrue(createButton.waitForExistence(timeout: t(8)), "Expected Routines screen")

        let starterRoutine = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Starter — Full Body A"))
            .firstMatch

        if !starterRoutine.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "RoutineEditor_esMX_StarterRoutineMissing")
        }
        XCTAssertTrue(starterRoutine.exists, "Expected seeded starter routine to appear.")
        tapSafely(starterRoutine)

        let localizedBench = app.staticTexts["Press de banca"].firstMatch
        if !localizedBench.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "RoutineEditor_esMX_LocalizedExerciseMissing")
        }
        XCTAssertTrue(localizedBench.exists, "Expected routine flow to show a localized built-in exercise name.")
    }

    func test_createRoutine_exercisePickerRowsRemainSelectable_whenThumbnailsAreEnabled() {
        app = UITestLaunch.app(
            start: "routines",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_THUMBNAILS": "1"]
        )
        app.launch()

        let createButton = createRoutineButton(in: app)
        XCTAssertTrue(createButton.waitForExistence(timeout: t(8)), "Expected Routines screen")
        tapSafely(createButton)

        let editorNav = newRoutineNavigationBar(in: app)
        XCTAssertTrue(editorNav.waitForExistence(timeout: t(6)), "Expected New Routine editor")

        let addExercise = addExerciseButton(in: app)
        if !addExercise.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "RoutineEditor_Thumbnail_AddExerciseMissing")
        }
        XCTAssertTrue(addExercise.exists, "Expected Add exercise action in routine editor.")
        tapSafely(addExercise)

        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "RoutineEditor_Thumbnail_PickerMissing")
        }
        XCTAssertTrue(searchField.exists, "Expected Exercise picker search field.")
        XCTAssertTrue(searchField.waitForExistence(timeout: t(6)), "Expected Exercise picker search field.")
        searchField.tap()
        searchField.typeText("Bench Press")

        let benchLabel = app.staticTexts["Bench Press"].firstMatch
        if !benchLabel.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "RoutineEditor_Thumbnail_BenchRowMissing")
        }
        XCTAssertTrue(benchLabel.exists, "Expected Bench Press picker row to remain present with thumbnails enabled.")
        tapSafely(benchLabel)

        XCTAssertTrue(
            addExerciseButton(in: app).waitForExistence(timeout: t(6)),
            "Expected to return to the routine editor after choosing an exercise."
        )
    }

    // MARK: - Helpers

    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func waitForStableRoutineRowCount(in app: XCUIApplication,
                                              minimum: Int,
                                              timeout: TimeInterval) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var lastCount = -1
        var stableSamples = 0

        while Date() < deadline {
            let count = routineRowCount(in: app)

            if count >= minimum {
                if count == lastCount {
                    stableSamples += 1
                } else {
                    stableSamples = 0
                    lastCount = count
                }

                if stableSamples >= 3 {
                    return count
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        return routineRowCount(in: app)
    }

    private func routineRowCount(in app: XCUIApplication) -> Int {
        let tableCells = app.tables.cells.count
        if tableCells > 0 { return tableCells }

        let directCells = app.cells.count
        if directCells > 0 { return directCells }

        return 0
    }
    
    private func createRoutineButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Create routine", "Crear rutina")
        ).firstMatch
    }

    private func addExerciseButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Add exercise", "Agregar ejercicio")
        ).firstMatch
    }

    private func newRoutineNavigationBar(in app: XCUIApplication) -> XCUIElement {
        let english = app.navigationBars["New Routine"]
        if english.exists { return english }
        return app.navigationBars["Nueva rutina"]
    }
}
