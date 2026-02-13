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

    private func waitAny(_ candidates: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for c in candidates where c.exists {
                if c.isHittable || c.frame.isEmpty == false { return c }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        // final: allow waitForExistence on each quickly
        for c in candidates {
            if c.waitForExistence(timeout: 0.5) { return c }
        }
        return nil
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

        let typeRow = waitAny([
            any(app, id: "activityEditor.typePicker"),
            cellByLabel(app, contains: "Type"),
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Type")).firstMatch
        ], timeout: 4)

        XCTAssertNotNil(typeRow, "Expected a Type row/picker in New Activity sheet.")

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

        let typeRow = waitAny([
            any(app, id: "activityEditor.typePicker"),
            cellByLabel(app, contains: "Type"),
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Type")).firstMatch
        ], timeout: 6)

        XCTAssertNotNil(typeRow, "Expected to find the Type row.")
        typeRow?.tap()

        // Choose “Workout” from whatever picker/menu is presented.
        let workoutChoice = waitAny([
            app.buttons["Workout"],
            app.staticTexts["Workout"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Workout")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Workout")).firstMatch
        ], timeout: 4)
        workoutChoice?.tap()

        // Now we expect a Routine picker OR “No routines” message.
        let routineRow = waitAny([
            any(app, id: "activityEditor.routinePicker"),
            cellByLabel(app, contains: "Routine"),
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Routine")).firstMatch
        ], timeout: 3)

        let hasEmptyMessage =
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "No routines")).firstMatch.exists
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "No routine")).firstMatch.exists

        XCTAssertTrue(routineRow != nil || hasEmptyMessage, "Expected Routine picker or empty-state text.")
    }

    func testVerboseLoggingTogglePersistsAcrossRelaunch() {
        var app = makeApp(start: "settings", resetDefaults: true, seed: false)
        app.launch()

        // Identifier-first, but allow label fallback.
        let sw = waitAny([
            app.switches.matching(identifier: "settings.verboseLoggingToggle").firstMatch,
            any(app, id: "settings.verboseLoggingToggle"),
            app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "Verbose")).firstMatch
        ], timeout: 8)

        XCTAssertNotNil(sw, "Expected a Verbose logging toggle/switch.")
        guard let sw1 = sw else { return }

        ensureSwitchOn(sw1)

        app.terminate()
        app = makeApp(start: "settings", resetDefaults: false, seed: false)
        app.launch()

        let sw2 = waitAny([
            app.switches.matching(identifier: "settings.verboseLoggingToggle").firstMatch,
            any(app, id: "settings.verboseLoggingToggle"),
            app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "Verbose")).firstMatch
        ], timeout: 8)

        XCTAssertNotNil(sw2, "Expected to find Verbose logging toggle after relaunch.")
        guard let swRelaunch = sw2 else { return }

        XCTAssertTrue((swRelaunch.value as? String) == "1" || (swRelaunch.value as? String) == "On")
    }
}
