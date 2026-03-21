import XCTest

// File: workouttrackerUITests/ActiveSessionsHomeSmokeUITests.swift
//
// Coverage for the Home-screen active-session reminder:
// 1) Home shows unfinished sessions when they exist.
// 2) Resume returns the user to the active session screen.
// 3) Past-day sessions offer a quick Finish action and disappear after finishing.
//
// Notes:
// - Seed data for these tests is created in workouttrackerUITestHost/workouttrackerUITestHostApp.swift
//   behind UITESTS_ACTIVE_SESSIONS=1.
// - We intentionally follow the existing UITestLaunch + in-memory host patterns.

final class ActiveSessionsHomeSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_homeShowsActiveSessionsSection_withTodayAndPastDaySessions() {
        let app = makeApp()
        app.launch()

        let section = app.el("Home.ActiveSessions.Section")
        if !section.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "ActiveSessions_SectionMissing")
        }
        XCTAssertTrue(section.exists, "Expected the Home screen to show the Active Sessions section.")

        XCTAssertTrue(
            app.staticTexts["UITest — Active Today"].waitForExistence(timeout: t(4)),
            "Expected today's active session to be visible on Home."
        )

        XCTAssertTrue(
            app.staticTexts["UITest — Active Previous Day"].waitForExistence(timeout: t(4)),
            "Expected the previous-day active session to be visible on Home."
        )

        XCTAssertTrue(
            app.staticTexts["Previous day"].waitForExistence(timeout: t(2)),
            "Expected the previous-day badge for stale active sessions."
        )

        XCTAssertTrue(
            app.buttons.matching(identifier: "Home.ActiveSessions.Resume").count >= 2,
            "Expected one Resume button per active session."
        )
    }

    func test_homeResumeOpensTodaySession() {
        let app = makeApp()
        app.launch()

        let resumeButtons = app.buttons.matching(identifier: "Home.ActiveSessions.Resume")
        XCTAssertGreaterThanOrEqual(resumeButtons.count, 1, "Expected at least one Resume button on Home.")

        let firstResume = resumeButtons.element(boundBy: 0)
        if !firstResume.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "ActiveSessions_ResumeMissing")
        }
        XCTAssertTrue(firstResume.exists, "Expected Resume button for today's session.")
        tapSafely(firstResume)

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "ActiveSessions_SessionScreenMissing")
        }
        XCTAssertTrue(sessionScreen.exists, "Expected Resume to navigate to the active workout session screen.")

        XCTAssertTrue(
            app.navigationBars.staticTexts["UITest — Active Today"].waitForExistence(timeout: t(3))
            || app.staticTexts["UITest — Active Today"].exists,
            "Expected the resumed session to be the today's active session, sorted first on Home."
        )
    }

    func test_homeFinishRemovesPastDaySession() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["UITest — Active Previous Day"].waitForExistence(timeout: t(4)),
            "Expected the previous-day active session before finishing."
        )

        let finishButtons = app.buttons.matching(identifier: "Home.ActiveSessions.Finish")
        let finish = finishButtons.firstMatch
        if !finish.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "ActiveSessions_FinishMissing")
        }
        XCTAssertTrue(finish.exists, "Expected a quick Finish button for stale active sessions.")
        tapSafely(finish)

        XCTAssertFalse(
            app.staticTexts["UITest — Active Previous Day"].waitForExistence(timeout: t(2)),
            "Expected the previous-day session to disappear from Home after quick finish."
        )

        XCTAssertTrue(
            app.staticTexts["UITest — Active Today"].exists,
            "Expected the current-day active session to remain after finishing the stale one."
        )

        XCTAssertEqual(
            app.buttons.matching(identifier: "Home.ActiveSessions.Finish").count,
            0,
            "Expected no stale-session Finish buttons after the only past-day session is completed."
        )
    }
    
    func test_homeResume_survivesRotation_andStaysOnSessionScreen() {
        let app = makeApp()
        app.launch()

        let resume = app.buttons.matching(identifier: "Home.ActiveSessions.Resume").element(boundBy: 0)
        if !resume.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "ActiveSessions_Rotation_ResumeMissing")
        }
        XCTAssertTrue(resume.exists, "Expected at least one Resume button on Home.")
        tapSafely(resume)

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "ActiveSessions_Rotation_SessionMissingBeforeRotate")
        }
        XCTAssertTrue(sessionScreen.exists, "Expected to be on WorkoutSession screen before rotation.")

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        let continueButton = app.buttons["WorkoutSession.ContinueButton"]
        if !continueButton.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "ActiveSessions_Rotation_SessionLostAfterRotate")
        }

        XCTAssertTrue(
            sessionScreen.exists || continueButton.exists,
            "Expected active session to remain visible after rotation instead of dropping back to Home."
        )
    }
    

    func test_dayTimelineResume_centersSameActionableSet() {
        let app = UITestLaunch.app(
            start: "calendar",
            reset: true,
            seed: false,
            extraEnv: ["UITESTS_ACTIVE_SESSIONS_SCROLL": "1"]
        )
        app.launch()

        XCTAssertTrue(app.staticTexts["DayTimeline.Debug.ActivitiesCount"].waitForExistence(timeout: t(6)))
        XCTAssertEqual(app.staticTexts["DayTimeline.Debug.ActivitiesCount"].label, "Activities: 1")
        XCTAssertEqual(app.staticTexts["DayTimeline.Debug.WorkoutsCount"].label, "Workouts: 1")

        let openWorkout = app.buttons["DayTimeline.WorkoutCard.DefaultAction"].firstMatch
        if !openWorkout.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "DayTimelineResume_OpenControlMissing")
        }
        XCTAssertTrue(openWorkout.exists, "Expected DayTimeline.WorkoutCard.DefaultAction.")
        tapSafely(openWorkout)

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "DayTimelineResume_SessionMissing")
        }
        XCTAssertTrue(sessionScreen.exists, "Expected Day timeline resume to open the session screen.")

        let focusedRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if !focusedRow.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "DayTimelineResume_ActionableRowMissing")
        }

        assertApproximatelyVerticallyCentered(
            focusedRow,
            in: app,
            debugName: "Day timeline actionable row"
        )
    }

    func test_homeResume_centersActionableSet() {
        let app = makeScrollableResumeApp()
        app.launch()

        let resume = app.buttons.matching(identifier: "Home.ActiveSessions.Resume").element(boundBy: 0)
        if !resume.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "ActiveSessions_Centering_ResumeMissing")
        }
        XCTAssertTrue(resume.exists, "Expected Resume button on Home.")
        tapSafely(resume)

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "ActiveSessions_Centering_SessionMissing")
        }
        XCTAssertTrue(sessionScreen.exists, "Expected resumed session screen.")

        let focusedRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if !focusedRow.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "ActiveSessions_Centering_ActionableRowMissing")
        }

        assertApproximatelyVerticallyCentered(
            focusedRow,
            in: app,
            debugName: "Resume actionable row"
        )
    }

    // MARK: - Helpers
    
    private func makeScrollableResumeApp() -> XCUIApplication {
        UITestLaunch.app(
            start: "home",
            reset: true,
            seed: false,
            extraEnv: [
                "UITESTS_ACTIVE_SESSIONS_SCROLL": "1"
            ]
        )
    }

    private func makeApp() -> XCUIApplication {
        UITestLaunch.app(
            start: "home",
            reset: true,
            seed: false,
            extraEnv: ["UITESTS_ACTIVE_SESSIONS": "1"]
        )
    }
    
    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func revealAndTap(_ el: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: t(2)), "Expected Day timeline scroll view.")

        var attempts = 0
        while !el.isHittable && attempts < 4 {
            scrollView.swipeUp()
            attempts += 1
        }

        if !el.isHittable {
            attachUITestDebug(app, name: "DayTimelineResume_OpenControlStillNotHittable")
        }
        XCTAssertTrue(el.isHittable, "Expected Day timeline workout-open control to become hittable after scrolling into view.")
        el.tap()
    }
}
