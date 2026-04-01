import XCTest

// Coverage for the Home-screen active-session reminder:
// 1) Home shows unfinished sessions when they exist.
// 2) Resume returns the user to the active session screen.
// 3) Previous-day unfinished sessions route through recovery instead of being finished inline.

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

        let todayResume = app.buttons["Home.ActiveSessions.Resume.Today"]
        let previousDayResume = app.buttons["Home.ActiveSessions.Resume.PreviousDay"]

        XCTAssertTrue(
            todayResume.waitForExistence(timeout: t(2)),
            "Expected Resume button for today's active session."
        )
        XCTAssertTrue(
            previousDayResume.waitForExistence(timeout: t(2)),
            "Expected Resume button for previous-day active session."
        )
    }

    func test_homePastDaySession_showsFinishAndAttentionState() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["UITest — Active Previous Day"].waitForExistence(timeout: t(4)))
        XCTAssertTrue(app.staticTexts["Previous day"].waitForExistence(timeout: t(2)))
        XCTAssertTrue(app.staticTexts["Needs attention"].waitForExistence(timeout: t(2)))

        let finishButton = staleFinishButton(in: app)
        XCTAssertTrue(finishButton.waitForExistence(timeout: t(4)), "Expected stale session finish button on Home.")
    }

    func test_homeResumeOpensTodaySession() {
        let app = makeApp()
        app.launch()

        let todayResume = todayResumeButton(in: app)
        XCTAssertTrue(todayResume.waitForExistence(timeout: t(4)))
        tapSafely(todayResume)

        let sessionScreen = app.el("WorkoutSession.Screen")
        XCTAssertTrue(sessionScreen.waitForExistence(timeout: t(8)))
        XCTAssertTrue(sessionScreen.exists, "Expected Resume to navigate to the active workout session screen.")

        XCTAssertTrue(
            app.navigationBars.staticTexts["UITest — Active Today"].waitForExistence(timeout: t(3))
            || app.staticTexts["UITest — Active Today"].exists,
            "Expected the resumed session to be the today's active session."
        )
    }
    
    func test_homeResumeForPastDaySession_showsRecoveryActions() {
        let app = makeApp()
        app.launch()

        let staleResume = staleResumeButton(in: app)
        XCTAssertTrue(staleResume.waitForExistence(timeout: t(4)), "Expected Resume button for stale active session.")
        tapSafely(staleResume)

        XCTAssertTrue(waitForRecoveryPrompt(in: app, timeout: t(4)), "Expected stale-session recovery prompt.")

        XCTAssertTrue(app.buttons["Resume"].exists, "Expected recovery prompt Resume action.")
        XCTAssertTrue(app.buttons["Finish now"].exists, "Expected Finish now action for stale recovery.")
        XCTAssertTrue(app.buttons["Keep for later"].exists, "Expected Keep for later action for stale recovery.")
        XCTAssertTrue(app.buttons["Discard"].exists, "Expected Discard action for stale recovery.")
    }

    func test_homeFinishNowRemovesPastDaySession() {
        let app = makeApp()
        app.launch()

        let staleResume = staleResumeButton(in: app)
        XCTAssertTrue(staleResume.waitForExistence(timeout: t(4)), "Expected stale session Resume button.")
        tapSafely(staleResume)

        let finishNow = recoveryPromptFinishButton(in: app)
        XCTAssertTrue(finishNow.waitForExistence(timeout: t(4)), "Expected Finish now action for stale active sessions.")
        tapSafely(finishNow)

        XCTAssertFalse(
            app.staticTexts["UITest — Active Previous Day"].waitForExistence(timeout: t(2)),
            "Expected the previous-day session to disappear from Home after Finish now."
        )
    }

    func test_homeResume_survivesRotation_andStaysOnSessionScreen() {
        let app = makeApp()
        app.launch()

        let resume = todayResumeButton(in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: t(4)), "Expected Resume button for today's active session.")
        tapSafely(resume)

        let sessionScreen = app.el("WorkoutSession.Screen")
        XCTAssertTrue(sessionScreen.waitForExistence(timeout: t(8)), "Expected to be on WorkoutSession screen before rotation.")

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        let continueButton = app.buttons["WorkoutSession.ContinueButton"]
        XCTAssertTrue(
            sessionScreen.waitForExistence(timeout: t(6)) || continueButton.waitForExistence(timeout: t(6)),
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

        let openWorkout = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier == %@ OR label == %@",
                    "DayTimeline.WorkoutCard.DefaultAction",
                    "UITest — Active Scroll"
                )
            )
            .firstMatch

        if !openWorkout.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "DayTimelineResume_OpenControlMissing")
        }
        XCTAssertTrue(openWorkout.exists, "Expected DayTimeline.WorkoutCard.DefaultAction.")
        revealAndTap(openWorkout, in: app)

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "DayTimelineResume_SessionMissing")
        }
        XCTAssertTrue(sessionScreen.exists, "Expected Day timeline resume to open the session screen.")

        let focusedRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if !focusedRow.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "DayTimelineResume_ActionableRowMissing")
        }

        assertActionableRowVisibleInWorkingArea(
            focusedRow,
            in: app,
            debugName: "Day timeline actionable row"
        )
    }

    func test_homeResume_centersActionableSet() {
        let app = makeScrollableResumeApp()
        app.launch()

        let resume = todayResumeButton(in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: t(4)), "Expected Resume button on Home.")
        tapSafely(resume)

        let sessionScreen = app.el("WorkoutSession.Screen")
        XCTAssertTrue(sessionScreen.waitForExistence(timeout: t(8)), "Expected resumed session screen.")

        let focusedRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        XCTAssertTrue(focusedRow.waitForExistence(timeout: t(6)), "Expected actionable set row after resume.")

        assertActionableRowVisibleInWorkingArea(
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
            disableAnimations: false,
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

    private func waitForRecoveryPrompt(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let labels = ["Resume", "Finish now", "Keep for later", "Discard"]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if labels.allSatisfy({ app.buttons[$0].exists }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return labels.allSatisfy { app.buttons[$0].exists }
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
    
    private func todayResumeButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Home.ActiveSessions.Resume.Today"]
    }

    private func staleResumeButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Home.ActiveSessions.Resume.PreviousDay"]
    }

    private func staleFinishButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Home.ActiveSessions.Finish.PreviousDay"]
    }

    private func recoveryPromptFinishButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(
                format: "label == %@ AND identifier != %@",
                "Finish now",
                "Home.ActiveSessions.Finish.PreviousDay"
            )
        ).firstMatch
    }
}
