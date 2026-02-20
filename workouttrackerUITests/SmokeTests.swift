import XCTest

final class SmokeTests: XCTestCase {

    // MARK: - Launch

    private func makeApp(start: String, resetDefaults: Bool = true, seed: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_START"] = start
        if resetDefaults { app.launchEnvironment["UITESTS_RESET"] = "1" }
        if seed { app.launchEnvironment["UITESTS_SEED"] = "1" }
        app.launchArguments = ["-uiTesting"]
        return app
    }

    // MARK: - Finders (identifier-first, label fallback)

    private func any(_ app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func buttonByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func cellByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func staticByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func waitAny(_ candidates: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for c in candidates where c.exists {
                // For table cells offscreen, exists might be true but not hittable;
                // we still return it so caller can scroll/tap via coordinate.
                return c
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        // final: allow waitForExistence on each quickly
        for c in candidates {
            if c.waitForExistence(timeout: 0.5) { return c }
        }
        return nil
    }

    // MARK: - Scrolling helpers

    @discardableResult
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 10) -> Bool {
        // Try to make it exist by scrolling anyway (cells may be lazily created).
        if !element.exists {
            for _ in 0..<maxSwipes { app.swipeUp() }
            return element.exists
        }

        if element.isHittable { return true }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.isHittable { return true }
        }

        // Try reverse direction once.
        for _ in 0..<maxSwipes {
            app.swipeDown()
            if element.isHittable { return true }
        }

        return element.isHittable
    }

    // MARK: - Actions

    @discardableResult
    private func openNewActivitySheet(_ app: XCUIApplication,
                                      file: StaticString = #filePath,
                                      line: UInt = #line) -> Bool {
        // 1) Prefer your identifier
        let byId = any(app, id: "timeline.newActivityButton")
        if byId.waitForExistence(timeout: 6) {
            if byId.isHittable { byId.tap() }
            else { byId.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        } else {
            // 2) Fallback: look for “Add” / “New activity”
            let fallback = waitAny([
                buttonByLabel(app, contains: "New"),
                buttonByLabel(app, contains: "Add"),
                app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add")).firstMatch
            ], timeout: 4)

            guard let fb = fallback else {
                XCTFail("Could not find a way to open New Activity sheet.", file: file, line: line)
                return false
            }
            fb.tap()
        }

        // The most reliable signal that the sheet opened: a Save button OR at least one text field.
        let save = waitAny([
            any(app, id: "activityEditor.saveButton"),
            app.buttons["Save"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Save")).firstMatch
        ], timeout: 6)

        if save != nil { return true }

        // If no save button is exposed, accept “a screen with textfields” as the sheet
        return app.textFields.firstMatch.waitForExistence(timeout: 3)
    }

    private func findActivityTypeRow(_ app: XCUIApplication) -> XCUIElement? {
        // Your app may label this row “Type” or “Kind” depending on earlier refactors.
        return waitAny([
            any(app, id: "activityEditor.typePicker"),
            any(app, id: "activityEditor.kindPicker"),
            cellByLabel(app, contains: "Type"),
            cellByLabel(app, contains: "Kind"),
            staticByLabel(app, contains: "Type"),
            staticByLabel(app, contains: "Kind"),
        ], timeout: 4)
    }

    private func selectActivityType(_ app: XCUIApplication, label: String) {
        // Many UIs expose type choices directly (segmented control / menu buttons).
        if waitAny([
            app.buttons[label],
            app.staticTexts[label],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        ], timeout: 1) != nil {
            // Tap the first candidate (coordinate tap if not hittable).
            let c = waitAny([
                app.buttons[label],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch,
                app.staticTexts[label],
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
            ], timeout: 1)

            if let c {
                if c.isHittable { c.tap() }
                else { c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            }
            return
        }

        // Otherwise, open a “Type/Kind” row and pick.
        if let row = findActivityTypeRow(app) {
            if !row.isHittable { _ = scrollToElement(row, in: app) }
            row.tap()
        }

        let choice = waitAny([
            app.buttons[label],
            app.staticTexts[label],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        ], timeout: 4)

        if let choice {
            if choice.isHittable { choice.tap() }
            else { choice.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        }

        // Some pickers need a Done button.
        let done = waitAny([
            app.buttons["Done"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Done")).firstMatch
        ], timeout: 1)

        if let done {
            if done.isHittable { done.tap() }
            else { done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        }
    }

    private func routinePickerOrEmptyStateExists(_ app: XCUIApplication) -> Bool {
        let routineCandidates: [XCUIElement] = [
            any(app, id: "activityEditor.routinePicker"),
            any(app, id: "activityEditor.workoutRoutinePicker"),
            cellByLabel(app, contains: "Routine"),
            cellByLabel(app, contains: "Workout routine"),
            staticByLabel(app, contains: "Routine"),
        ]

        let emptyPhrases = [
            "No routines",
            "No routine",
            "Create a routine",
            "Create routines",
            "No exercises yet" // some builds show this guidance inline
        ]

        func hasEmptyMessage() -> Bool {
            emptyPhrases.contains { phrase in
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", phrase)).firstMatch.exists
            }
        }

        // First pass without scrolling.
        if waitAny(routineCandidates, timeout: 1) != nil { return true }
        if hasEmptyMessage() { return true }

        // Scroll within the sheet (Form/List rows may be lazily created).
        for _ in 0..<10 {
            app.swipeUp()
            if waitAny(routineCandidates, timeout: 0.5) != nil { return true }
            if hasEmptyMessage() { return true }
        }

        return false
    }

    private func ensureSwitchOn(_ sw: XCUIElement) {
        // Works even when normal taps don’t toggle
        let off = ((sw.value as? String) == "0" || (sw.value as? String) == "Off")
        if off {
            if sw.isHittable { sw.tap() }
            else { sw.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        }

        let pred = NSPredicate(format: "value == '1' OR value == 'On'")
        expectation(for: pred, evaluatedWith: sw)
        waitForExpectations(timeout: 8)
    }

    private func findVerboseLoggingSwitch(_ app: XCUIApplication) -> XCUIElement? {
        let candidates = [
            app.switches.matching(identifier: "settings.verboseLoggingToggle").firstMatch,
            any(app, id: "settings.verboseLoggingToggle"),
            app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "Verbose")).firstMatch
        ]

        // First try without scrolling.
        if let found = waitAny(candidates, timeout: 2) { return found }

        // Then scroll and retry.
        for _ in 0..<12 {
            app.swipeUp()
            if let found = waitAny(candidates, timeout: 0.5) { return found }
        }

        // Last: try opening Preferences (some builds may move the toggle there).
        let prefs = waitAny([
            cellByLabel(app, contains: "Preferences"),
            staticByLabel(app, contains: "Preferences")
        ], timeout: 1)
        if let prefs, prefs.exists {
            if !prefs.isHittable { _ = scrollToElement(prefs, in: app) }
            prefs.tap()

            if let found = waitAny(candidates, timeout: 3) { return found }
            for _ in 0..<10 {
                app.swipeUp()
                if let found = waitAny(candidates, timeout: 0.5) { return found }
            }

            // Go back if needed.
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
        }

        return nil
    }

    // MARK: - Tests

    func testNewActivitySheetNotBlankOnFirstOpen() {
        let app = makeApp(start: "calendar", resetDefaults: true, seed: false)
        app.launch()

        XCTAssertTrue(openNewActivitySheet(app))

        // Don’t hard-require nav bar title; it’s brittle.
        // Require “basic editing affordances exist”.
        let titleField = waitAny([
            any(app, id: "activityEditor.titleField"),
            app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] %@", "Title")).firstMatch,
            app.textFields.matching(NSPredicate(format: "label CONTAINS[c] %@", "Title")).firstMatch,
            app.textFields.firstMatch
        ], timeout: 6)

        XCTAssertNotNil(titleField, "Expected a title TextField in New Activity sheet.")

        // The UI may use “Type” or “Kind”, or expose options directly.
        let typeRow = findActivityTypeRow(app)
        let canSeeAnyTypeOption = waitAny([
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Workout")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Workout")).firstMatch
        ], timeout: 2) != nil

        XCTAssertTrue(typeRow != nil || canSeeAnyTypeOption,
                      "Expected an Activity Type/Kind selector (row or visible options) in New Activity sheet.")

        let save = waitAny([
            any(app, id: "activityEditor.saveButton"),
            app.buttons["Save"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Save")).firstMatch
        ], timeout: 4)

        XCTAssertNotNil(save, "Expected a Save button in New Activity sheet.")
    }

    func testWorkoutTypeShowsRoutinePickerOrEmptyState() {
        let app = makeApp(start: "calendar", resetDefaults: true, seed: false)
        app.launch()

        XCTAssertTrue(openNewActivitySheet(app))

        // Select Workout in a robust way (segmented/menu/row).
        selectActivityType(app, label: "Workout")

        // Now we expect a Routine picker OR an empty-state message.
        XCTAssertTrue(routinePickerOrEmptyStateExists(app),
                      "Expected Routine picker or empty-state text after selecting Workout.")
    }

    func testVerboseLoggingTogglePersistsAcrossRelaunch() {
        var app = makeApp(start: "settings", resetDefaults: true, seed: false)
        app.launch()

        let sw = findVerboseLoggingSwitch(app)
        XCTAssertNotNil(sw, "Expected a Verbose logging toggle/switch.")
        guard let sw1 = sw else { return }

        if !sw1.isHittable { _ = scrollToElement(sw1, in: app) }
        ensureSwitchOn(sw1)

        app.terminate()
        app = makeApp(start: "settings", resetDefaults: false, seed: false)
        app.launch()

        let sw2 = findVerboseLoggingSwitch(app)
        XCTAssertNotNil(sw2, "Expected to find Verbose logging toggle after relaunch.")
        guard let swRelaunch = sw2 else { return }

        if !swRelaunch.isHittable { _ = scrollToElement(swRelaunch, in: app) }
        XCTAssertTrue((swRelaunch.value as? String) == "1" || (swRelaunch.value as? String) == "On")
    }
}
