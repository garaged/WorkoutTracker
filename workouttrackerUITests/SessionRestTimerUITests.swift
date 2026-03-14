import XCTest

final class SessionRestTimerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = UITestLaunch.app(
            start: "session",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_REST_TIMER_SHORT": "1"]
        )
        app.launch()

        startFirstRoutineSessionIfNeeded(app)
        assertOnSessionScreen(app)
    }

    func test_restTimer_showsOverdue_extends_and_resolves() {
        let firstDone = firstDoneToggle(in: app)
        XCTAssertTrue(firstDone.waitForExistence(timeout: 10), "Expected at least one set row to start rest timer flow.")
        firstDone.tap()

        XCTAssertTrue(app.otherElements["RestTimerView.Card"].waitForExistence(timeout: 10),
                      "Expected the rest timer card to appear after completing a set.")

        let continueButton = app.buttons["WorkoutSession.ContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10), "Expected Continue button on session screen.")
        continueButton.tap()

        XCTAssertTrue(waitForTimerToDisappear(timeout: 10),
                      "Expected Continue to resolve and clear the active rest timer.")

        let toolbarTimer = app.buttons["WorkoutSession.RestTimerButton"]
        XCTAssertTrue(toolbarTimer.waitForExistence(timeout: 10), "Expected toolbar rest timer button.")
        toolbarTimer.tap()

        XCTAssertTrue(app.otherElements["RestTimerView.Card"].waitForExistence(timeout: 5),
                      "Expected manual rest timer to appear.")

        XCTAssertTrue(waitForReadyOrOverdue(timeout: 8),
                      "Expected timer to remain visible and enter Ready/Overdue state after crossing zero.")

        let extend30 = app.buttons["RestTimerControlsView.Extend30Button"]
        XCTAssertTrue(extend30.waitForExistence(timeout: 4), "Expected +30s control on rest timer.")
        extend30.tap()

        XCTAssertTrue(waitForCountdownAfterExtend(timeout: 5),
                      "Expected +30s to push the timer back into countdown state.")

        continueButton.tap()
        XCTAssertTrue(waitForTimerToDisappear(timeout: 10),
                      "Expected next workout action to resolve and clear the timer card.")
    }

    // MARK: - Session navigation

    private var doneTogglePredicate: NSPredicate {
        NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    "WorkoutSetEditorRow.", ".DoneToggle")
    }

    private func firstDoneToggle(in app: XCUIApplication) -> XCUIElement {
        let buttons = app.buttons.matching(doneTogglePredicate)
        if buttons.count > 0 { return buttons.firstMatch }

        let switches = app.switches.matching(doneTogglePredicate)
        if switches.count > 0 { return switches.firstMatch }

        return app.otherElements.matching(doneTogglePredicate).firstMatch
    }

    private func waitForSessionScreen(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if firstDoneToggle(in: app).exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return firstDoneToggle(in: app).exists
    }

    private func startFirstRoutineSessionIfNeeded(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if waitForSessionScreen(app: app, timeout: 8.0) { return }

        attachUITestDebug(app, name: "SessionRouteBootstrapFailed", file: file, line: line)
        XCTFail(
            """
            Expected UITESTS_START=session to bootstrap directly into a seeded workout session.
            The UITestHost session route did not reach the session screen.
            """,
            file: file,
            line: line
        )
    }

    private func assertOnSessionScreen(_ app: XCUIApplication,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        if waitForSessionScreen(app: app, timeout: 12) { return }

        attachUITestDebug(app, name: "Not on session screen", file: file, line: line)
        XCTFail("Expected to land on session screen.", file: file, line: line)
    }

    // MARK: - Timer waits

    private func waitForTimerToDisappear(timeout: TimeInterval) -> Bool {
        let timerCard = app.otherElements["RestTimerView.Card"]
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if !timerCard.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return !timerCard.exists
    }

    private func waitForReadyOrOverdue(timeout: TimeInterval) -> Bool {
        let ready = app.staticTexts["RestTimerView.ReadyLabel"]
        let overdue = app.staticTexts["RestTimerView.OverdueLabel"]
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if ready.exists || overdue.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return ready.exists || overdue.exists
    }

    private func waitForCountdownAfterExtend(timeout: TimeInterval) -> Bool {
        let ready = app.staticTexts["RestTimerView.ReadyLabel"]
        let overdue = app.staticTexts["RestTimerView.OverdueLabel"]
        let paused = app.staticTexts["RestTimerView.PausedLabel"]
        let timerCard = app.otherElements["RestTimerView.Card"]

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if timerCard.exists && !ready.exists && !overdue.exists && !paused.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return timerCard.exists && !ready.exists && !overdue.exists && !paused.exists
    }
}
