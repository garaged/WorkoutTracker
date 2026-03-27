import XCTest

final class LocalizationSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_settingsRendersSpanishTitle_underSpanishMexicoLocale() {
        let app = makeApp(start: "settings")
        app.launch()

        XCTAssertTrue(app.navigationBars["Configuración"].waitForExistence(timeout: t(8)), "Expected settings title to be localized.")
    }

    func test_exerciseLibrary_showsLocalizedBuiltInName_underSpanishMexicoLocale() {
        let app = makeApp(start: "exercise-library", seed: true)
        app.launch()

        let library = app.el("ExerciseLibrary.Screen")
        if !library.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "Localization_ExerciseLibrary_esMX_ScreenMissing")
        }
        XCTAssertTrue(library.exists, "Expected Exercise library screen.")

        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "Localization_ExerciseLibrary_esMX_SearchMissing")
        }
        XCTAssertTrue(searchField.exists, "Expected Exercise library search field.")

        searchField.tap()
        searchField.typeText("Press de banca")

        let localizedBench = app.staticTexts["Press de banca"].firstMatch
        if !localizedBench.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "Localization_ExerciseLibrary_esMX_BenchMissing")
        }
        XCTAssertTrue(localizedBench.exists, "Expected the library search to show a localized built-in Bench Press row.")
    }

    func test_exercisePicker_searchesLocalizedBuiltInName_underSpanishMexicoLocale() {
        let app = makeApp(start: "exercise-picker", seed: true)
        app.launch()

        let picker = app.el("ExercisePicker.Screen")
        if !picker.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "Localization_ExercisePicker_esMX_ScreenMissing")
        }
        XCTAssertTrue(picker.exists, "Expected Exercise picker screen.")

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: t(6)), "Expected Exercise picker search field.")
        searchField.tap()
        searchField.typeText("Press de banca")

        let localizedBench = app.staticTexts["Press de banca"].firstMatch
        if !localizedBench.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "Localization_ExercisePicker_esMX_LocalizedSearchFailed")
        }
        XCTAssertTrue(localizedBench.exists, "Expected localized picker search to match Bench Press under es-MX.")
    }

    func test_exercisePicker_localizedRowRemainsTappable_whenThumbnailsAreEnabled_underSpanishMexicoLocale() {
        let app = makeApp(
            start: "exercise-picker",
            seed: true,
            extraEnv: ["UITESTS_THUMBNAILS": "1"]
        )
        app.launch()

        let picker = app.el("ExercisePicker.Screen")
        if !picker.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "Localization_ExercisePicker_esMX_ThumbnailScreenMissing")
        }
        XCTAssertTrue(picker.exists, "Expected Exercise picker screen.")

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: t(6)), "Expected Exercise picker search field.")
        searchField.tap()
        searchField.typeText("Press de banca")

        let localizedBenchLabel = app.staticTexts["Press de banca"].firstMatch
        if !localizedBenchLabel.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "Localization_ExercisePicker_esMX_ThumbnailRowMissing")
        }
        XCTAssertTrue(localizedBenchLabel.exists, "Expected the localized Bench Press picker row to remain present when thumbnails are enabled.")

        tapSafely(localizedBenchLabel)

        XCTAssertTrue(
            picker.exists,
            "Expected the standalone picker UITest route to remain on screen after tapping a row."
        )
    }

    func test_progressDashboardAndDetailRenderSpanishCopy() {
        let app = makeApp(start: "progress", seed: true, extraEnv: ["UITESTS_PROGRESS": "1"])
        app.launch()

        let dashboard = app.el("Progress.Dashboard.Screen")
        if !dashboard.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "Localization_Progress_esMX_DashboardMissing")
        }
        XCTAssertTrue(dashboard.exists, "Expected Progress dashboard screen.")
        XCTAssertTrue(app.staticTexts["Tendencias de entrenamiento"].waitForExistence(timeout: t(4)), "Expected localized Progress dashboard header.")

        let firstExercise = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Progress.Dashboard.StrengthExerciseButton.")
        ).firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: t(6)), "Expected at least one seeded strength drill-down button.")
        tapSafely(firstExercise)

        let detail = app.el("Progress.Detail.Screen")
        if !detail.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "Localization_Progress_esMX_DetailMissing")
        }
        XCTAssertTrue(detail.exists, "Expected exercise detail screen after tapping a dashboard exercise.")
        XCTAssertTrue(app.staticTexts["Récords personales"].waitForExistence(timeout: t(4)), "Expected localized exercise detail section title.")
    }

    func test_linkedSessionShowsSpanishSegmentCopy() {
        let app = makeApp(
            start: "session",
            seed: true,
            extraEnv: ["UITESTS_LINKED_FLOW": "1"]
        )
        app.launch()

        let currentSegment = app.otherElements["SessionSegmentHeaderView.Current.warmUp"]
        if !currentSegment.waitForExistence(timeout: t(10)) {
            attachUITestDebug(app, name: "Localization_LinkedSession_esMX_HeaderMissing")
        }
        XCTAssertTrue(currentSegment.exists, "Expected linked workout flow to start in the warm-up segment.")
        XCTAssertTrue(app.staticTexts["Segmento actual"].waitForExistence(timeout: t(4)), "Expected localized current-segment subtitle.")
        XCTAssertTrue(app.staticTexts["Calentamiento"].waitForExistence(timeout: t(4)), "Expected localized warm-up title.")
        XCTAssertTrue(app.buttons["Omitir calentamiento"].waitForExistence(timeout: t(4)), "Expected localized skip warm-up action.")
    }

    private func makeApp(
        start: String,
        seed: Bool = false,
        extraEnv: [String: String] = [:]
    ) -> XCUIApplication {
        UITestLaunch.app(
            start: start,
            reset: true,
            seed: seed,
            extraEnv: extraEnv.merging(["UITESTS_LOCALIZATION": "1"]) { _, new in new },
            extraArgs: ["-AppleLanguages", "(es-MX)", "-AppleLocale", "es_MX"]
        )
    }

    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
