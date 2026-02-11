import XCTest

// File: workouttrackerUITests/SmokeTests.swift

final class SmokeTests: XCTestCase {
    
    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func makeApp(start: String, resetDefaults: Bool = true, seed: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_START"] = start
        if resetDefaults { app.launchEnvironment["UITESTS_RESET"] = "1" }
        if seed { app.launchEnvironment["UITESTS_SEED"] = "1" }
        app.launchArguments = ["-uiTesting"]
        return app
    }

    private func find(_ app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    private func tapNewActivityButton(_ app: XCUIApplication,
                                      file: StaticString = #filePath,
                                      line: UInt = #line) -> Bool {
        let byId = find(app, id: "timeline.newActivityButton")
        if byId.waitForExistence(timeout: 6) {
            if byId.isHittable {
                byId.tap()
            } else {
                byId.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return true
        }

        attachDebug(app, name: "tapNewActivityButton", file: file, line: line)
        XCTFail("Could not find/tap New Activity button.", file: file, line: line)
        return false
    }

    private func attachDebug(_ app: XCUIApplication,
                             name: String,
                             file: StaticString,
                             line: UInt) {
        let shot = XCUIScreen.main.screenshot()
        let a1 = XCTAttachment(screenshot: shot)
        a1.name = "\(name) screenshot"
        a1.lifetime = .keepAlways
        add(a1)

        let a2 = XCTAttachment(string: app.debugDescription)
        a2.name = "\(name) hierarchy"
        a2.lifetime = .keepAlways
        add(a2)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var swipes = 0
        while (!element.exists || !element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    func testNewActivitySheetNotBlankOnFirstOpen() {
        let app = makeApp(start: "calendar", resetDefaults: true, seed: false)
        app.launch()

        tapNewActivityButton(app)

        XCTAssertTrue(app.navigationBars["New Activity"].waitForExistence(timeout: 4))

        XCTAssertTrue(el(app, "activityEditor.titleField").waitForExistence(timeout: 4))
        XCTAssertTrue(el(app, "activityEditor.typePicker").waitForExistence(timeout: 4))
        XCTAssertTrue(el(app, "activityEditor.saveButton").waitForExistence(timeout: 4))
    }

    func testWorkoutTypeShowsRoutinePickerOrEmptyState() {
        let app = makeApp(start: "calendar", resetDefaults: true, seed: false)
        app.launch()

        XCTAssertTrue(tapNewActivityButton(app))
        guard app.navigationBars["New Activity"].waitForExistence(timeout: 4) else { return }

        let typeRow = find(app, id: "activityEditor.typePicker")
        XCTAssertTrue(typeRow.waitForExistence(timeout: 4.0))
        typeRow.tap()

        if app.staticTexts["Workout"].waitForExistence(timeout: 1.5) {
            app.staticTexts["Workout"].tap()
        } else if app.buttons["Workout"].waitForExistence(timeout: 1.5) {
            app.buttons["Workout"].tap()
        }

        let routineRow = find(app, id: "activityEditor.routinePicker")
        let hasPicker = routineRow.waitForExistence(timeout: 2.0)
        let hasEmptyMessage = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS[c] %@", "No routines"))
            .firstMatch.exists

        XCTAssertTrue(hasPicker || hasEmptyMessage, "Expected Routine picker or empty-state text.")
    }

    func testVerboseLoggingTogglePersistsAcrossRelaunch() {
        var app = makeApp(start: "settings", resetDefaults: true, seed: false)
        app.launch()

        let sw = app.descendants(matching: .switch)
            .matching(identifier: "settings.verboseLoggingToggle")
            .firstMatch

        scrollTo(sw, in: app)
        XCTAssertTrue(sw.waitForExistence(timeout: 8))

        ensureSwitchOn(sw)

        app.terminate()
        app = makeApp(start: "settings", resetDefaults: false, seed: false)
        app.launch()

        let sw2 = app.descendants(matching: .switch)
            .matching(identifier: "settings.verboseLoggingToggle")
            .firstMatch

        scrollTo(sw2, in: app)
        XCTAssertTrue(sw2.waitForExistence(timeout: 8))

        XCTAssertTrue((sw2.value as? String) == "1" || (sw2.value as? String) == "On")
    }
    
    private func ensureSwitchOn(_ sw: XCUIElement) {
        let isOff = ((sw.value as? String) == "0" || (sw.value as? String) == "Off")
        if isOff {
            sw.tap()
            // If SwiftUI doesn’t toggle from a normal tap, use a coordinate tap on the control area.
            if ((sw.value as? String) == "0" || (sw.value as? String) == "Off") {
                sw.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
        }

        let pred = NSPredicate(format: "value == '1' OR value == 'On'")
        expectation(for: pred, evaluatedWith: sw)
        waitForExpectations(timeout: 8)
    }
}
