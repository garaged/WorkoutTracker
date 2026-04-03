import XCTest

// File: workouttrackerUITests/DistanceUnitsSmokeUITests.swift
//
// Coverage for the new distance-unit preference:
// 1) Settings can switch from kilometers to miles.
// 2) The selected unit persists across relaunch and reaches active workout logging UI.
//
// Notes:
// - This intentionally follows the current suite's launch/seeding patterns.
// - Seeded cardio coverage relies on workouttrackerUITestHost seeding a starter cardio routine.

final class DistanceUnitsSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_settings_distanceUnit_canBeChangedToMiles() {
        let app = UITestLaunch.app(start: "settings", reset: true, seed: false)
        app.launch()

        XCTAssertTrue(
            waitForDistanceUnitPicker(in: app, timeout: t(6)),
            "Expected Settings screen to expose the distance unit picker."
        )

        XCTAssertTrue(selectDistanceUnit(.mi, in: app), "Expected to change Distance unit to miles.")

        XCTAssertTrue(
            distanceUnitSummaryContains("Miles", in: app),
            "Expected Settings to reflect the selected distance unit."
        )
    }

    func test_distanceUnit_milesPersistsIntoSeededCardioSession() {
        var app = UITestLaunch.app(start: "settings", reset: true, seed: false)
        app.launch()

        XCTAssertTrue(
            waitForDistanceUnitPicker(in: app, timeout: t(6)),
            "Expected Settings screen to expose the distance unit picker."
        )
        XCTAssertTrue(selectDistanceUnit(.mi, in: app), "Expected to change Distance unit to miles.")

        app.terminate()

        // Relaunch without reset so the selected preference survives into the workout flow.
        app = UITestLaunch.app(start: "calendar", reset: false, seed: true)
        app.launch()

        startSessionFromTimelineBlock(named: "UITest — Seeded Starter Cardio", in: app)

        XCTAssertTrue(
            waitForStartedCardioSession(in: app, timeout: t(12)),
            "Expected to start a seeded cardio workout or tracked activity session"
        )

        let miLabel = firstDistanceLabel(in: app, unitSymbol: "mi")
        if !miLabel.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "DistanceUnits_MilesLabelMissing")
        }
        XCTAssertTrue(miLabel.exists, "Expected the active session distance field to use miles after relaunch.")
    }

    // MARK: - Settings helpers
    
    private func waitForDistanceUnitPicker(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let picker = app.el("settings.distanceUnitPicker")
        if picker.waitForExistence(timeout: min(timeout, 1.5)) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            swipeScrollableUp(app)
            if picker.waitForExistence(timeout: 0.4) {
                return true
            }
        }

        attachUITestDebug(app, name: "DistanceUnits_PickerMissing")
        return false
    }

    private enum DistanceChoice {
        case km
        case mi

        var pickerLabel: String {
            switch self {
            case .km: return "Kilometers (km)"
            case .mi: return "Miles (mi)"
            }
        }

        var unitWord: String {
            switch self {
            case .km: return "Kilometers"
            case .mi: return "Miles"
            }
        }
    }

    @discardableResult
    private func selectDistanceUnit(_ choice: DistanceChoice, in app: XCUIApplication) -> Bool {
        let picker = app.el("settings.distanceUnitPicker")
        if !picker.waitForExistence(timeout: t(6)) {
            // Scroll in case the row starts below the fold on smaller devices.
            for _ in 0..<10 {
                app.swipeUp()
                if picker.exists { break }
            }
        }

        guard picker.exists else {
            attachUITestDebug(app, name: "DistanceUnits_PickerMissing")
            return false
        }

        tapSafely(picker)

        let choiceCandidates: [XCUIElement] = [
            app.buttons[choice.pickerLabel],
            app.staticTexts[choice.pickerLabel],
            app.menuItems[choice.pickerLabel],
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", choice.pickerLabel)).firstMatch,
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", choice.unitWord)).firstMatch
        ]

        guard let target = waitAny(choiceCandidates, timeout: t(4)) else {
            attachUITestDebug(app, name: "DistanceUnits_ChoiceMissing_\(choice.unitWord)")
            return false
        }

        tapSafely(target)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        return true
    }

    private func distanceUnitSummaryContains(_ word: String, in app: XCUIApplication) -> Bool {
        let direct = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", word))
            .firstMatch

        if direct.waitForExistence(timeout: t(2)) { return true }

        for _ in 0..<8 {
            app.swipeUp()
            if direct.exists { return true }
        }
        return false
    }

    // MARK: - Session helpers

    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
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

    private func swipeScrollableUp(_ app: XCUIApplication) {
        if app.tables.firstMatch.exists { app.tables.firstMatch.swipeUp(); return }
        if app.collectionViews.firstMatch.exists { app.collectionViews.firstMatch.swipeUp(); return }
        if app.scrollViews.firstMatch.exists { app.scrollViews.firstMatch.swipeUp(); return }
        app.swipeUp()
    }

    private func startSessionFromTimelineBlock(named title: String, in app: XCUIApplication) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", title)
        let blockTitle = app.descendants(matching: .any).matching(predicate).firstMatch

        if !blockTitle.waitForExistence(timeout: t(2)) {
            for _ in 0..<12 {
                swipeScrollableUp(app)
                if blockTitle.exists { break }
            }
        }

        if !blockTitle.exists {
            attachUITestDebug(app, name: "DistanceUnits_BlockNotFound")
            XCTFail("Expected timeline to show the seeded cardio activity block")
            return
        }

        tapSafely(blockTitle)

        let startOverlay = app.buttons.matching(identifier: "DayTimeline.WorkoutOverlay.Start").firstMatch
        if startOverlay.waitForExistence(timeout: t(2)) {
            tapSafely(startOverlay)
            return
        }

        swipeScrollableUp(app)
        if startOverlay.waitForExistence(timeout: t(1.5)) {
            tapSafely(startOverlay)
        }
    }

    private var doneTogglePredicate: NSPredicate {
        NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
            "WorkoutSetEditorRow.",
            ".DoneToggle"
        )
    }

    private func setToggleQuery(in app: XCUIApplication) -> XCUIElementQuery {
        let buttons = app.buttons.matching(doneTogglePredicate)
        if buttons.count > 0 { return buttons }

        let switches = app.switches.matching(doneTogglePredicate)
        if switches.count > 0 { return switches }

        return app.otherElements.matching(doneTogglePredicate)
    }

    private func waitForAnySetRow(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if setToggleQuery(in: app).count > 0 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return setToggleQuery(in: app).count > 0
    }

    private func firstDistanceLabel(in app: XCUIApplication, unitSymbol: String) -> XCUIElement {
        let exactCompact = app.staticTexts["Dist (\(unitSymbol))"]
        if exactCompact.exists { return exactCompact }

        let exactFull = app.staticTexts["Distance (\(unitSymbol))"]
        if exactFull.exists { return exactFull }

        return app.descendants(matching: .staticText)
            .matching(NSPredicate(format: "label == %@ OR label == %@", "Dist (\(unitSymbol))", "Distance (\(unitSymbol))"))
            .firstMatch
    }
    
    private func waitForStartedCardioSession(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let trackedActivityScreen = app.otherElements["TrackedActivitySession.Screen"]
        let miDistanceLabel = firstDistanceLabel(in: app, unitSymbol: "mi")
        let kmDistanceLabel = firstDistanceLabel(in: app, unitSymbol: "km")

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if setToggleQuery(in: app).count > 0 { return true }
            if trackedActivityScreen.exists { return true }
            if miDistanceLabel.exists || kmDistanceLabel.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        if trackedActivityScreen.waitForExistence(timeout: 0.5) { return true }
        if miDistanceLabel.waitForExistence(timeout: 0.5) { return true }
        if kmDistanceLabel.waitForExistence(timeout: 0.5) { return true }

        return setToggleQuery(in: app).count > 0
    }
}
