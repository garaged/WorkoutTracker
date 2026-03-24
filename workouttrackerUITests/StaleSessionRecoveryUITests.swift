import XCTest

final class StaleSessionRecoveryUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_keepForLater_suppressesRepeatedPrompt_sameDay() {
        let app = makeApp()
        app.launch()

        let staleResume = staleResumeButton(in: app)
        XCTAssertTrue(staleResume.waitForExistence(timeout: t(4)))
        tapSafely(staleResume)

        let keepForLater = app.buttons["Keep for later"]
        XCTAssertTrue(keepForLater.waitForExistence(timeout: t(4)), "Expected Keep for later action.")
        tapSafely(keepForLater)

        XCTAssertFalse(app.buttons["Keep for later"].exists, "Expected recovery prompt to dismiss after Keep for later.")

        let staleResumeAgain = staleResumeButton(in: app)
        XCTAssertTrue(staleResumeAgain.waitForExistence(timeout: t(4)))
        tapSafely(staleResumeAgain)

        XCTAssertFalse(
            app.buttons["Keep for later"].waitForExistence(timeout: t(2)),
            "Expected stale recovery prompt to stay suppressed for the rest of the day."
        )
        XCTAssertTrue(
            app.el("WorkoutSession.Screen").waitForExistence(timeout: t(6)),
            "Expected suppressed stale session to open directly after Keep for later."
        )
    }

    func test_discard_removesStaleReminder() {
        let app = makeApp()
        app.launch()

        let staleResume = staleResumeButton(in: app)
        XCTAssertTrue(staleResume.waitForExistence(timeout: t(4)))
        tapSafely(staleResume)

        let discard = app.buttons["Discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: t(4)), "Expected Discard action.")
        tapSafely(discard)

        XCTAssertFalse(
            app.staticTexts["UITest — Active Previous Day"].waitForExistence(timeout: t(2)),
            "Expected discarded stale session to disappear from Home."
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

    private func score(_ button: XCUIElement, anchor: XCUIElement) -> CGFloat {
        let vertical = abs(button.frame.midY - anchor.frame.midY)
        let horizontal = abs(button.frame.midX - anchor.frame.midX)
        return vertical * 3 + horizontal
    }
    
    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
    
    private func staleResumeButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Home.ActiveSessions.Resume.PreviousDay"]
    }
}
