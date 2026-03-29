import XCTest

final class SmokeTests: XCTestCase {

    // MARK: - App bootstrap

    private func makeApp(start: String, resetDefaults: Bool = true, seed: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_START"] = start
        if resetDefaults { app.launchEnvironment["UITESTS_RESET"] = "1" }
        if seed { app.launchEnvironment["UITESTS_SEED"] = "1" }
        app.launchArguments = ["-uiTesting"]
        return app
    }

    // MARK: - Generic finders

    private func any(_ app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func cellByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func staticByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func buttonByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
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

    private func swipeUpInSheet(_ app: XCUIApplication) {
        // Prefer the sheet’s scroll view (SwiftUI Form is usually a scroll view)
        let sv = app.scrollViews.firstMatch
        if sv.exists { sv.swipeUp() }
        else { app.swipeUp() }
    }

    // MARK: - Open New Activity sheet

    @discardableResult
    private func openNewActivitySheet(_ app: XCUIApplication) -> Bool {
        // Prefer an identifier if you have it
        let newBtn = any(app, id: "timeline.newActivityButton")
        if newBtn.waitForExistence(timeout: 4) {
            if newBtn.isHittable { newBtn.tap() }
            else { newBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        } else {
            // Fallbacks: “Add” button, plus, etc.
            let fallbacks: [XCUIElement] = [
                app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add")).firstMatch,
                buttonByLabel(app, contains: "Add"),
                buttonByLabel(app, contains: "New")
            ]
            guard let fb = waitAny(fallbacks, timeout: 3) else { return false }
            fb.tap()
        }

        // Sheet opened signal
        return any(app, id: "activityEditor.saveButton").waitForExistence(timeout: 6)
            || app.buttons["Save"].waitForExistence(timeout: 6)
            || app.textFields.firstMatch.waitForExistence(timeout: 6)
    }

    // MARK: - Select Workout type (segmented OR picker)

    private func selectWorkoutTypeIfPossible(_ app: XCUIApplication) {
        // 1) Segmented control is the most common
        let segCandidates: [XCUIElement] = [
            app.segmentedControls.buttons["Workout"],
            app.segmentedControls.buttons["Entrenamiento"],
            app.buttons["Workout"],
            app.buttons["Entrenamiento"],
            buttonByLabel(app, contains: "Workout"),
            buttonByLabel(app, contains: "Entrenamiento")
        ]
        if let seg = waitAny(segCandidates, timeout: 2) {
            if !seg.isHittable { swipeUpInSheet(app) }
            if seg.isHittable { seg.tap() }
            else { seg.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            return
        }

        // 2) Otherwise try a picker row/menu
        let typeRowCandidates: [XCUIElement] = [
            any(app, id: "activityEditor.typePicker"),
            cellByLabel(app, contains: "Type"),
            cellByLabel(app, contains: "Kind"),
            staticByLabel(app, contains: "Type"),
            staticByLabel(app, contains: "Kind")
        ]
        if let typeRow = waitAny(typeRowCandidates, timeout: 2) {
            if !typeRow.isHittable { swipeUpInSheet(app) }
            typeRow.tap()

            let workoutChoice = waitAny([
                app.buttons["Workout"],
                app.buttons["Entrenamiento"],
                app.staticTexts["Workout"],
                app.staticTexts["Entrenamiento"],
                buttonByLabel(app, contains: "Workout"),
                staticByLabel(app, contains: "Workout"),
            ], timeout: 3)

            if let workoutChoice {
                workoutChoice.tap()
            }

            if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        }
    }

    // MARK: - Routine picker / empty state detection

    private func routinePickerOrEmptyStateExists(_ app: XCUIApplication) -> Bool {
        // Identifiers (best case)
        let byIdPicker = any(app, id: "activityEditor.routinePicker")
        let byIdEmpty  = any(app, id: "activityEditor.routineEmptyState")

        // Broad “routine-ish” fallback: label or identifier contains routine/rutina/plan
        let routineish = app.descendants(matching: .any).matching(
            NSPredicate(format:
                "identifier CONTAINS[c] 'routine' OR label CONTAINS[c] 'routine' OR label CONTAINS[c] 'rutina' OR label CONTAINS[c] 'workout routine' OR label CONTAINS[c] 'plan'"
            )
        ).firstMatch

        func hasEmptyText() -> Bool {
            let phrases = [
                "No routines", "No routine", "No routines yet",
                "Sin rutinas", "No hay rutinas",
                "Create a routine", "Crea una rutina",
                "No workout routines"
            ]
            return phrases.contains { p in
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", p)).firstMatch.exists
            }
        }

        // Immediate check
        if byIdPicker.exists || byIdEmpty.exists || routineish.exists { return true }
        if hasEmptyText() { return true }

        // Scroll to force SwiftUI Form rows to materialize
        for _ in 0..<24 {
            swipeUpInSheet(app)
            if byIdPicker.exists || byIdEmpty.exists || routineish.exists { return true }
            if hasEmptyText() { return true }
        }
        return false
    }

    // MARK: - Verbose logging toggle finder (container-safe)

    private func findVerboseSwitch(_ app: XCUIApplication) -> XCUIElement? {
        // Identifier might be on a container, not the switch
        let container = any(app, id: "settings.verboseLoggingToggle")
        if container.waitForExistence(timeout: 2) {
            let sw = container.switches.firstMatch
            if sw.exists { return sw }
        }

        // Fallback: any switch with label containing "Verbose"
        let sw2 = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "Verbose")).firstMatch
        if sw2.exists { return sw2 }

        // Scroll and retry
        for _ in 0..<18 {
            app.swipeUp()
            if container.exists {
                let sw = container.switches.firstMatch
                if sw.exists { return sw }
            }
            if sw2.exists { return sw2 }
        }
        return nil
    }

    private func ensureSwitchOn(_ sw: XCUIElement, app: XCUIApplication) {
        if !sw.isHittable { app.swipeUp() }

        func isOn(_ v: String) -> Bool { v == "1" || v.lowercased() == "on" || v.lowercased() == "true" }

        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let v = (sw.value as? String) ?? ""
            if isOn(v) { return }
            sw.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
    }

    // MARK: - Tests

    func testNewActivitySheetNotBlankOnFirstOpen() {
        let app = makeApp(start: "calendar", resetDefaults: true, seed: false)
        app.launch()

        XCTAssertTrue(openNewActivitySheet(app), "Could not open New Activity sheet.")

        XCTAssertTrue(
            any(app, id: "activityEditor.titleField").exists || app.textFields.firstMatch.exists,
            "Expected a title TextField in New Activity sheet."
        )

        XCTAssertTrue(
            any(app, id: "activityEditor.saveButton").exists || app.buttons["Save"].exists,
            "Expected a Save button in New Activity sheet."
        )
    }

    func testWorkoutTypeShowsRoutinePickerOrEmptyState() {
        let app = makeApp(start: "calendar", resetDefaults: true, seed: true)
        app.launch()

        XCTAssertTrue(openNewActivitySheet(app), "Could not open New Activity sheet.")

        // Try to select Workout (segmented or picker). If it is already selected, this is a no-op.
        selectWorkoutTypeIfPossible(app)

        XCTAssertTrue(
            routinePickerOrEmptyStateExists(app),
            "Expected Routine picker or empty-state text after selecting Workout."
        )
    }

    func testHomeInjectedSessionExerciseRoute_opensSessionAndCentersTargetRow() {
        let app = makeApp(start: "home", resetDefaults: true, seed: false)
        app.launchEnvironment["UITESTS_ACTIVE_SESSIONS_SCROLL"] = "1"
        app.launchEnvironment["UITESTS_DEEP_LINK_SMOKE"] = "1"
        app.launch()

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "PR1_DeepLinkSmoke_NotOnSession")
        }
        XCTAssertTrue(sessionScreen.exists, "Expected injected PR1 deep link to open WorkoutSession.Screen from Home.")

        let focusedRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if !focusedRow.waitForExistence(timeout: 8) {
            attachUITestDebug(app, name: "PR1_DeepLinkSmoke_ActionableRowMissing")
        }
        XCTAssertTrue(focusedRow.exists, "Expected injected session-exercise deep link to reveal the actionable set row.")

        assertApproximatelyVerticallyCentered(
            focusedRow,
            in: app,
            tolerance: 170,
            debugName: "PR1 deep-link actionable row"
        )
    }

    func testVerboseLoggingTogglePersistsAcrossRelaunch() {
        var app = makeApp(start: "settings", resetDefaults: true, seed: false)
        app.launch()

        guard let sw1 = findVerboseSwitch(app) else {
            XCTFail("Expected a Verbose logging toggle/switch.")
            return
        }
        ensureSwitchOn(sw1, app: app)

        app.terminate()

        // Relaunch without reset
        app = makeApp(start: "settings", resetDefaults: false, seed: false)
        app.launch()

        guard let sw2 = findVerboseSwitch(app) else {
            XCTFail("Expected Verbose logging switch after relaunch.")
            return
        }

        let v2 = (sw2.value as? String) ?? ""
        XCTAssertTrue(v2 == "1" || v2.lowercased() == "on" || v2.lowercased() == "true")
    }
}
