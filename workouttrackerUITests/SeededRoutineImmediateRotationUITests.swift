import XCTest

final class SeededRoutineImmediateRotationUITests: XCTestCase {
    private enum Launch {
        static let uiTests = "1"
        static let start = "session"
        static let seed = "1"
        static let linkedFlow = "1"
        static let reset = "1"
    }

    private enum Screen {
        static let session = "WorkoutSession.Screen"
    }

    private enum SeededData {
        static let sessionTitle = "UITest — Linked Main"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    func test_seededCalendarSession_tapToStart_thenRotateImmediately_staysOnSession() throws {
        let app = XCUIApplication()
        configureLaunch(app)

        app.launch()
        dismissInterruptionsIfPresent(in: app)

        let calendarSession = findVisibleCalendarSession(in: app, titled: SeededData.sessionTitle)
        XCTAssertTrue(
            calendarSession.waitForExistence(timeout: 10),
            """
            Expected seeded calendar session "\(SeededData.sessionTitle)" to exist.
            This test depends on the UITESTS_START=session + UITESTS_SEED=1 + UITESTS_LINKED_FLOW=1 host path.
            """
        )
        XCTAssertTrue(
            calendarSession.isHittable,
            """
            Expected seeded calendar session "\(SeededData.sessionTitle)" to be directly hittable without scrolling.
            """
        )

        calendarSession.tap()

        let sessionScreen = app.otherElements[Screen.session]

        // Some flows open the session directly; others require pressing Start first.
        if !sessionScreen.waitForExistence(timeout: 1) {
            let startButton = findVisibleStartButton(in: app)
            XCTAssertTrue(
                startButton.waitForExistence(timeout: 3),
                """
                Expected either direct navigation to \(Screen.session) or a visible Start action
                after tapping the seeded calendar session.
                """
            )
            XCTAssertTrue(
                startButton.isHittable,
                "Expected start button to be hittable without scrolling."
            )

            startButton.tap()
        }

        // Rotate as soon as possible after the start action.
        XCUIDevice.shared.orientation = .landscapeLeft

        XCTAssertTrue(
            sessionScreen.waitForExistence(timeout: 5),
            "Expected workout session screen to remain visible after immediate rotation."
        )
        XCTAssertTrue(
            sessionScreen.exists,
            "Expected workout session screen to still exist after immediate rotation."
        )

        XCUIDevice.shared.orientation = .portrait

        XCTAssertTrue(
            sessionScreen.waitForExistence(timeout: 5),
            "Expected workout session screen to remain visible after rotating back to portrait."
        )
    }

    // MARK: - Launch

    private func configureLaunch(_ app: XCUIApplication) {
        app.launchEnvironment["UITESTS"] = Launch.uiTests
        app.launchEnvironment["UITESTS_RESET"] = Launch.reset
        app.launchEnvironment["UITESTS_START"] = Launch.start
        app.launchEnvironment["UITESTS_SEED"] = Launch.seed
        app.launchEnvironment["UITESTS_LINKED_FLOW"] = Launch.linkedFlow
    }

    // MARK: - Lookup

    private func findVisibleCalendarSession(in app: XCUIApplication, titled title: String) -> XCUIElement {
        let candidates: [XCUIElement] = [
            app.buttons[title],
            app.staticTexts[title],
            app.otherElements[title],
            app.cells[title],
            app.cells.staticTexts[title],
            app.collectionViews.cells.staticTexts[title],
            app.tables.cells.staticTexts[title]
        ]

        for candidate in candidates where candidate.exists && candidate.isHittable {
            return candidate
        }

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return app.staticTexts[title]
    }

    private func findVisibleStartButton(in app: XCUIApplication) -> XCUIElement {
        let candidates: [XCUIElement] = [
            app.buttons["Start Workout"],
            app.buttons["Start"],
            app.buttons["Begin Workout"],
            app.buttons["Begin"],
            app.buttons["Continue"]
        ]

        for candidate in candidates where candidate.exists && candidate.isHittable {
            return candidate
        }

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return app.buttons["Start Workout"]
    }

    // MARK: - Helpers

    private func dismissInterruptionsIfPresent(in app: XCUIApplication) {
        let candidates = ["Allow", "OK", "Continue", "Don’t Allow", "Don't Allow"]

        for title in candidates {
            let button = app.buttons[title]
            if button.exists && button.isHittable {
                button.tap()
                return
            }
        }
    }
}
