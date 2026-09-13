import XCTest

final class EasyProQuickStartSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testProBaselinePreservesExistingHomeShell() {
        let app = UITestLaunch.app(start: "home", reset: true, seed: false)
        app.launch()

        let calendar = app.el("Home.Tile.Calendar")
        if !calendar.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "EasyPro_ProHomeMissing")
        }
        XCTAssertTrue(calendar.exists, "Expected existing installations and legacy UI suites to retain the Pro Home shell.")
        XCTAssertFalse(app.el("Easy.Home.JustStartTimer").exists)
    }

    func testEasyHomeExposesThreeStartsAndLaunchesCardioTimer() {
        let app = easyApp()
        app.launch()

        let follow = app.el("Easy.Home.FollowWorkout")
        let freestyle = app.el("Easy.Home.GymFreestyle")
        let timer = app.el("Easy.Home.JustStartTimer")
        if !timer.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "EasyPro_EasyHomeMissing")
        }
        XCTAssertTrue(follow.exists)
        XCTAssertTrue(freestyle.exists)
        XCTAssertTrue(timer.exists)

        timer.tap()
        let cardio = app.el("QuickStart.Style.cardio")
        if !cardio.waitForExistence(timeout: 4) {
            attachUITestDebug(app, name: "EasyPro_TimerStylesMissing")
        }
        XCTAssertTrue(cardio.exists)
        cardio.tap()

        let session = app.el("QuickStart.Session.Screen")
        if !session.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "EasyPro_TimerSessionMissing")
        }
        XCTAssertTrue(session.exists)
        XCTAssertTrue(app.el("QuickStart.Session.Pause").exists)
        XCTAssertTrue(app.staticTexts["Cardio"].exists)
    }

    func testEasyTimerPauseResumeAndFinishExposeCommittedState() {
        let app = easyApp()
        app.launch()

        let timer = app.el("Easy.Home.JustStartTimer")
        XCTAssertTrue(timer.waitForExistence(timeout: 6))
        timer.tap()

        let cardio = app.el("QuickStart.Style.cardio")
        XCTAssertTrue(cardio.waitForExistence(timeout: 4))
        cardio.tap()

        let pause = app.el("QuickStart.Session.Pause")
        XCTAssertTrue(pause.waitForExistence(timeout: 6))
        pause.tap()

        let resume = app.el("QuickStart.Session.Resume")
        XCTAssertTrue(resume.waitForExistence(timeout: 4))
        resume.tap()

        let finish = app.el("QuickStart.Session.Finish")
        XCTAssertTrue(finish.waitForExistence(timeout: 4))
        finish.tap()

        let done = app.el("QuickStart.Session.Done")
        if !done.waitForExistence(timeout: 4) {
            attachUITestDebug(app, name: "EasyPro_TimerCompletionMissing")
        }
        XCTAssertTrue(done.exists)
        XCTAssertTrue(app.staticTexts["Completed"].exists)
    }


    func testEasySettingsSwitchesToProWhenIdle() {
        let app = easyApp()
        app.launch()

        let settings = app.el("Easy.Home.Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 6))
        settings.tap()

        let pro = app.el("Settings.Experience.Pro")
        if !pro.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "EasyPro_ModeSwitchMissing")
        }
        XCTAssertTrue(pro.exists)
        pro.tap()

        let back = app.buttons["BackButton"]
        if !back.waitForExistence(timeout: 4) {
            attachUITestDebug(app, name: "EasyPro_SettingsBackMissing")
        }
        XCTAssertTrue(back.exists)
        back.tap()

        let calendar = app.el("Home.Tile.Calendar")
        if !calendar.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "EasyPro_ProHomeAfterReturningFromSettingsMissing")
        }
        XCTAssertTrue(calendar.exists)
    }

    private func easyApp() -> XCUIApplication {
        UITestLaunch.app(
            start: "home",
            reset: true,
            seed: false,
            extraEnv: ["UITESTS_EASY_MODE": "1"]
        )
    }
}
