import XCTest

final class LocalizationSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_settingsLaunchesUnderSpanishMexicoLocale() {
        let app = UITestLaunch.app(
            start: "settings",
            reset: true,
            seed: false,
            extraArgs: ["-AppleLanguages", "(es-MX)", "-AppleLocale", "es_MX"]
        )

        app.launch()

        let distancePicker = app.el("settings.distanceUnitPicker")
        if !distancePicker.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "Localization_Settings_esMX_LaunchFailed")
        }
        XCTAssertTrue(distancePicker.exists, "Expected Settings to render under es_MX locale.")
    }
}
