import XCTest

final class TrackedActivityHealthSettingsSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_autoSaveToggle_persistsAcrossRelaunch() {
        var app = UITestLaunch.app(start: "settings", reset: true, seed: false)
        app.launch()

        XCTAssertTrue(waitForAutoSaveToggle(in: app, timeout: t(8)), "Expected Settings to expose the Apple Health auto-save toggle.")
        XCTAssertTrue(setAutoSave(in: app, enabled: true), "Expected Apple Health auto-save to be enabled before relaunch. Actual value: \(String(describing: normalizedToggleValue(autoSaveToggle(in: app))))")

        app.terminate()

        app = UITestLaunch.app(start: "settings", reset: false, seed: false)
        app.launch()

        XCTAssertTrue(waitForAutoSaveToggle(in: app, timeout: t(8)), "Expected Settings to expose the Apple Health auto-save toggle after relaunch.")
        let relaunchedToggle = autoSaveToggle(in: app)
        if !waitForToggleValue(in: app, expected: "1", timeout: t(2.5)) {
            attachUITestDebug(app, name: "TrackedActivityHealthSettings_ToggleNotPersisted")
        }
        XCTAssertTrue(waitForToggleValue(in: app, expected: "1", timeout: t(2.5)), "Expected Apple Health auto-save to remain enabled after relaunch. Actual value: \(String(describing: normalizedToggleValue(relaunchedToggle)))")
    }

    private func autoSaveToggle(in app: XCUIApplication) -> XCUIElement {
        app.switches["settings.healthAutoSaveToggle"].firstMatch
    }

    private func nestedAutoSaveSwitch(in app: XCUIApplication) -> XCUIElement {
        autoSaveToggle(in: app).switches.firstMatch
    }

    private func waitForAutoSaveToggle(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let toggle = autoSaveToggle(in: app)
        if toggle.waitForExistence(timeout: min(timeout, 1.5)) { return true }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.collectionViews.firstMatch.exists {
                app.collectionViews.firstMatch.swipeUp()
            } else if app.tables.firstMatch.exists {
                app.tables.firstMatch.swipeUp()
            } else if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeUp()
            } else {
                app.swipeUp()
            }

            if toggle.waitForExistence(timeout: 0.4) { return true }
        }

        attachUITestDebug(app, name: "TrackedActivityHealthSettings_AutoSaveToggleMissing")
        return false
    }

    @discardableResult
    private func setAutoSave(in app: XCUIApplication, enabled: Bool) -> Bool {
        if normalizedToggleValue(autoSaveToggle(in: app)) == (enabled ? "1" : "0") {
            return true
        }

        let deadline = Date().addingTimeInterval(3.0)
        while Date() < deadline {
            tapAutoSaveSwitch(in: app)
            if waitForToggleValue(in: app, expected: enabled ? "1" : "0", timeout: 0.8) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        attachUITestDebug(app, name: "TrackedActivityHealthSettings_ToggleDidNotChange")
        return waitForToggleValue(in: app, expected: enabled ? "1" : "0", timeout: 0.5)
    }

    private func tapAutoSaveSwitch(in app: XCUIApplication) {
        let rowSwitch = autoSaveToggle(in: app)
        let nestedSwitch = nestedAutoSaveSwitch(in: app)

        if nestedSwitch.exists {
            tapSafely(nestedSwitch)
            return
        }

        if rowSwitch.exists {
            // The accessibility identifier is attached to a row-sized Switch element.
            // Tap near the trailing edge so UITests hit the actual toggle control instead of the label area.
            rowSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            return
        }

        tapSafely(app.staticTexts["Auto-save completed tracked activities to Apple Health"].firstMatch)
    }

    private func waitForToggleValue(in app: XCUIApplication, expected: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if normalizedToggleValue(autoSaveToggle(in: app)) == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return normalizedToggleValue(autoSaveToggle(in: app)) == expected
    }

    private func normalizedToggleValue(_ toggle: XCUIElement) -> String? {
        if let value = toggle.value as? String { return value }
        if let value = toggle.value as? NSNumber { return value.stringValue }
        return nil
    }

    private func tapSafely(_ element: XCUIElement) {
        guard element.exists else { return }
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
