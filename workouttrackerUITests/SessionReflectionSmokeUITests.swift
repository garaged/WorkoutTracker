import XCTest

final class SessionReflectionSmokeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Match the rest of the suite: use the existing UITestHost "session" route + seeding.
        app = UITestLaunch.app(start: "session", reset: true, seed: true)
        app.launch()

        startFirstRoutineSessionIfNeeded(app)
        assertOnSessionScreen(app)
    }

    func testFinishShowsReflectionSheet() {
        tapFinish(app)
        confirmFinishAndSave(app)

        XCTAssertTrue(
            waitForReflectionSheet(app, timeout: 6),
            "Expected Reflection sheet after finishing a session (only when no reflection exists yet).\nUI tree:\n\(app.debugDescription)"
        )

        dismissReflectionSheet(app)
    }

    // MARK: - Finish flow

    private func tapFinish(_ app: XCUIApplication) {
        let byId = app.buttons["WorkoutSession.FinishButton"]
        if byId.waitForExistence(timeout: 4) {
            byId.tap()
            return
        }

        // Fallback by label (in case the identifier was renamed).
        let byLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Finish")).firstMatch
        XCTAssertTrue(byLabel.waitForExistence(timeout: 4), "Expected a Finish button.\nUI tree:\n\(app.debugDescription)")
        byLabel.tap()
    }

    private func confirmFinishAndSave(_ app: XCUIApplication) {
        let candidates: [XCUIElement] = [
            app.buttons["WorkoutSession.FinishConfirmButton"],
            app.buttons["Finish & Save"],
            app.buttons["session.finish_workout.action"],
            app.descendants(matching: .button)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "finish_workout.action"))
                .firstMatch
        ]

        if let button = waitAny(candidates, timeout: 4) {
            button.tap()
            return
        }

        attachUITestDebug(app, name: "SessionReflection_FinishConfirmMissing")
        XCTFail("Expected Finish confirmation action.")
    }

    // MARK: - Reflection sheet detection/dismiss

    private func waitForReflectionSheet(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let byMoodId = app.otherElements["SessionReflection.Mood.great"]
        let byNotNowId = app.buttons["SessionReflection.NotNow"]
        let byNavTitle = app.navigationBars["Reflection"]
        let byHeaderText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "How did it go")).firstMatch

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if byMoodId.exists || byNotNowId.exists || byNavTitle.exists || byHeaderText.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return byMoodId.exists || byNotNowId.exists || byNavTitle.exists || byHeaderText.exists
    }

    private func dismissReflectionSheet(_ app: XCUIApplication) {
        // Preferred: identifier.
        let notNowById = app.buttons["SessionReflection.NotNow"]
        if notNowById.waitForExistence(timeout: 2) {
            notNowById.tap()
            return
        }

        // Fallback: label.
        let notNowByLabel = app.buttons.matching(NSPredicate(format: "label == %@", "Not now")).firstMatch
        XCTAssertTrue(notNowByLabel.waitForExistence(timeout: 2), "Expected Not now button on Reflection sheet.\nUI tree:\n\(app.debugDescription)")
        notNowByLabel.tap()
    }

    // MARK: - Navigation to Session (same style as Phase1LoggingSmokeUITests)

    private var doneTogglePredicate: NSPredicate {
        NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    "WorkoutSetEditorRow.", ".DoneToggle")
    }

    private func setToggleQuery(in app: XCUIApplication) -> XCUIElementQuery {
        let buttons = app.buttons.matching(doneTogglePredicate)
        if buttons.count > 0 { return buttons }

        let switches = app.switches.matching(doneTogglePredicate)
        if switches.count > 0 { return switches }

        return app.otherElements.matching(doneTogglePredicate)
    }

    private func waitForSessionScreen(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if setToggleQuery(in: app).count > 0 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return setToggleQuery(in: app).count > 0
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

        let shot = XCUIScreen.main.screenshot()
        let shotAttachment = XCTAttachment(screenshot: shot)
        shotAttachment.name = "UI Screenshot (not on session)"
        shotAttachment.lifetime = .keepAlways
        add(shotAttachment)

        let treeAttachment = XCTAttachment(string: app.debugDescription)
        treeAttachment.name = "UI Hierarchy Dump"
        treeAttachment.lifetime = .keepAlways
        add(treeAttachment)

        XCTFail("Expected to land on session screen.", file: file, line: line)
    }
    
    private func waitAny(_ candidates: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for c in candidates where c.exists { return c }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        for c in candidates {
            if c.waitForExistence(timeout: 0.5) { return c }
        }
        return nil
    }
}
