// workouttrackerUITests/ProgramsSettingsSmokeUITests.swift
import XCTest

final class ProgramsSettingsSmokeUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_settings_programs_opensProgramsScreen() {
        let app = UITestLaunch.app(start: "home", reset: true, seed: false)
        app.launch()

        // Try to open Settings (gear uses accessibilityLabel("Settings"))
        let settingsBtn = app.buttons["Settings"].firstMatch
        if settingsBtn.waitForExistence(timeout: 6) {
            settingsBtn.tap()
        } else {
            // fallback: any element containing Settings
            let anySettings = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings"))
                .firstMatch
            XCTAssertTrue(anySettings.waitForExistence(timeout: 6), "Expected a way to open Settings.")
            anySettings.tap()
        }

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8), "Expected Settings screen.")

        // Prefer the identifier you added
        let programs = app.el("settings.programsLink")
        if programs.waitForExistence(timeout: 3) {
            programs.tap()
        } else {
            let fallback = app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", "Programs")).firstMatch
            XCTAssertTrue(fallback.waitForExistence(timeout: 6), "Expected Programs row.")
            fallback.tap()
        }

        XCTAssertTrue(app.navigationBars["Programs"].waitForExistence(timeout: 8), "Expected Programs screen.")
    }
}
