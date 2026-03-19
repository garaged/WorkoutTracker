import XCTest

final class ProgressHubUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_progressDashboard_opensAndShowsSeededCards() {
        let app = makeApp()
        app.launch()

        let dashboard = app.el("Progress.Dashboard.Screen")
        if !dashboard.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "ProgressHub_DashboardMissing")
        }
        XCTAssertTrue(dashboard.exists, "Expected Progress dashboard screen.")

        let strengthCard = app.el("Progress.Dashboard.StrengthCard")
        XCTAssertTrue(strengthCard.waitForExistence(timeout: t(4)), "Expected Strength card on the Progress dashboard.")

        XCTAssertTrue(
            app.staticTexts["UITest Bench Press"].waitForExistence(timeout: t(4)),
            "Expected seeded primary exercise to appear on the Progress dashboard."
        )
    }

    func test_progressDashboard_opensExerciseDetailFromStrengthCard() {
        let app = makeApp()
        app.launch()

        let firstExercise = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Progress.Dashboard.StrengthExerciseButton.")
        ).firstMatch
        if !firstExercise.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "ProgressHub_StrengthExerciseMissing")
        }
        XCTAssertTrue(firstExercise.exists, "Expected at least one strength drill-down button on the dashboard.")
        tapSafely(firstExercise)

        let detail = app.el("Progress.Detail.Screen")
        if !detail.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "ProgressHub_DetailMissing")
        }
        XCTAssertTrue(detail.exists, "Expected exercise detail screen after tapping a dashboard exercise.")

        XCTAssertTrue(
            app.el("Progress.Detail.ExerciseName").waitForExistence(timeout: t(4)),
            "Expected exercise detail header to render."
        )
        XCTAssertTrue(
            app.el("Progress.Detail.PersonalRecordsSection").waitForExistence(timeout: t(4)),
            "Expected personal records section in exercise detail."
        )
        XCTAssertTrue(
            app.el("Progress.Detail.RecentPerformanceSection").waitForExistence(timeout: t(4)),
            "Expected recent performance section in exercise detail."
        )
    }

    func test_progressExerciseDetail_lowDataScenarioShowsHonestState() {
        let app = makeLowDataApp()
        app.launch()

        let firstExercise = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Progress.Dashboard.StrengthExerciseButton.")
        ).firstMatch
        if !firstExercise.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "ProgressHub_LowDataExerciseMissing")
        }
        XCTAssertTrue(firstExercise.exists, "Expected seeded sparse Progress history to expose an exercise drill-down.")
        tapSafely(firstExercise)

        let detail = app.el("Progress.Detail.Screen")
        if !detail.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "ProgressHub_LowDataDetailMissing")
        }
        XCTAssertTrue(detail.exists, "Expected exercise detail screen for the sparse Progress scenario.")

        let lowData = app.el("Progress.Detail.LowData")
        if !lowData.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "ProgressHub_LowDataDetailBannerMissing")
        }
        XCTAssertTrue(lowData.exists, "Expected exercise detail to present an honest low-data state.")
    }

    private func makeApp() -> XCUIApplication {
        UITestLaunch.app(
            start: "progress",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_PROGRESS": "1"]
        )
    }

    private func makeLowDataApp() -> XCUIApplication {
        UITestLaunch.app(
            start: "progress",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_PROGRESS_LOW_DATA": "1"]
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
