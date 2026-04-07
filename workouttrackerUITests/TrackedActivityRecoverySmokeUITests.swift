import XCTest

final class TrackedActivityRecoverySmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_keepForLater_suppressesPreviousDayPrompt_thenOpensDirectly() {
        let app = UITestLaunch.app(
            start: "activities",
            reset: true,
            seed: false,
            extraEnv: [
                "UITESTS_TRACKED_ACTIVITY_SEED": "1",
                "UITESTS_TRACKED_ACTIVITY_STALE": "1"
            ]
        )
        app.launch()

        let recoveryCard = app.el("Activities.Recovery.Card")
        XCTAssertTrue(recoveryCard.waitForExistence(timeout: t(4)), "Expected the tracked-activity recovery card.")
        tapSafely(recoveryCard)

        let keepForLater = app.buttons["Keep for later"]
        XCTAssertTrue(keepForLater.waitForExistence(timeout: t(4)), "Expected stale tracked-activity recovery prompt.")
        tapSafely(keepForLater)

        XCTAssertFalse(keepForLater.waitForExistence(timeout: t(1.5)), "Expected recovery prompt to dismiss after Keep for later.")

        let recoveryCardAgain = app.el("Activities.Recovery.Card")
        XCTAssertTrue(recoveryCardAgain.waitForExistence(timeout: t(3)))
        tapSafely(recoveryCardAgain)

        XCTAssertFalse(app.buttons["Keep for later"].waitForExistence(timeout: t(1.5)), "Expected recovery prompt to stay suppressed for the rest of the day.")
        XCTAssertTrue(app.el("TrackedActivitySession.Screen").waitForExistence(timeout: t(6)), "Expected suppressed tracked activity to open directly.")
    }

    func test_failedAppleHealthSave_followUpCardOpensSummary() {
        let app = UITestLaunch.app(
            start: "activities",
            reset: true,
            seed: false,
            extraEnv: [
                "UITESTS_TRACKED_ACTIVITY_SEED": "1",
                "UITESTS_TRACKED_ACTIVITY_EXPORT_FAILED": "1"
            ]
        )
        app.launch()

        let followUpCard = app.el("Activities.HealthFollowUp.Card")
        XCTAssertTrue(
            followUpCard.waitForExistence(timeout: t(4)),
            "Expected Apple Health follow-up card for failed tracked-activity export."
        )
        tapSafely(followUpCard)

        XCTAssertTrue(
            app.el("TrackedActivity.FinishSummary.Screen").waitForExistence(timeout: t(6)),
            "Expected the tracked-activity finish summary screen."
        )

        XCTAssertTrue(
            app.staticTexts["Apple Health"].waitForExistence(timeout: t(4)),
            "Expected Apple Health section in the summary."
        )

        XCTAssertTrue(
            app.staticTexts["Workout save state, Save failed"].waitForExistence(timeout: t(4)),
            "Expected failed Apple Health save state in the summary."
        )
    }

    private func tapSafely(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
