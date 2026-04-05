import XCTest

final class TrackedActivityLiveTimerSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_liveTimer_pauseAndResume_doesNotResetToZero() {
        let app = UITestLaunch.app(
            start: "tracked-session",
            reset: true,
            seed: false,
            extraEnv: [
                "UITESTS_TRACKED_ACTIVITY_SEED": "1",
                "UITESTS_TRACKED_ACTIVITY_LIVE": "1"
            ]
        )
        app.launch()

        let screen = app.el("TrackedActivitySession.Screen")
        if !screen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "TrackedActivityLiveTimer_ScreenMissing")
        }
        XCTAssertTrue(screen.exists, "Expected the seeded tracked-activity live screen.")

        let initialTimer = liveTimerLabel(in: app)
        XCTAssertTrue(initialTimer.waitForExistence(timeout: t(4)), "Expected a live duration value on the tracked-activity screen.")
        XCTAssertFalse(isZeroTimer(initialTimer.label), "Expected the seeded live timer to already be non-zero. Actual label: \(initialTimer.label)")

        XCTAssertTrue(pauseSession(in: app), "Expected Pause action for the live tracked activity.")
        XCTAssertTrue(resumeSession(in: app), "Expected Resume action after pausing the tracked activity.")

        RunLoop.current.run(until: Date().addingTimeInterval(1.2))

        let resumedTimer = liveTimerLabel(in: app)
        XCTAssertTrue(resumedTimer.exists, "Expected the live duration value to remain visible after resuming.")
        XCTAssertFalse(isZeroTimer(resumedTimer.label), "Expected the live timer to keep prior elapsed progress after resume. Actual label: \(resumedTimer.label)")
    }

    private func pauseSession(in app: XCUIApplication) -> Bool {
        guard scrollPauseButtonIntoView(in: app) else {
            attachUITestDebug(app, name: "TrackedActivityLiveTimer_PauseMissing")
            return false
        }

        let deadline = Date().addingTimeInterval(t(6))
        while Date() < deadline {
            let pauseButton = pauseButton(in: app)
            tapSafely(pauseButton)

            if resumeButton(in: app).waitForExistence(timeout: 0.8) {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        attachUITestDebug(app, name: "TrackedActivityLiveTimer_ResumeMissing")
        return resumeButton(in: app).exists
    }

    private func resumeSession(in app: XCUIApplication) -> Bool {
        let resume = resumeButton(in: app)
        guard resume.waitForExistence(timeout: t(4)) else {
            attachUITestDebug(app, name: "TrackedActivityLiveTimer_ResumeMissing")
            return false
        }

        tapSafely(resume)
        return pauseButton(in: app).waitForExistence(timeout: t(4)) || liveTimerLabel(in: app).exists
    }

    private func scrollPauseButtonIntoView(in app: XCUIApplication) -> Bool {
        let pause = pauseButton(in: app)
        if pause.waitForExistence(timeout: 1.0), pause.isHittable { return true }

        let deadline = Date().addingTimeInterval(t(4))
        while Date() < deadline {
            if pause.exists, pause.isHittable { return true }
            if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeUp()
            } else {
                app.swipeUp()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return pause.exists
    }

    private func pauseButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Pause")).firstMatch
    }

    private func resumeButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Resume")).firstMatch
    }

    private func liveTimerLabel(in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "label MATCHES %@", "^[0-9]+:[0-5][0-9](:[0-5][0-9])?$")
        return app.staticTexts.matching(predicate).firstMatch
    }

    private func isZeroTimer(_ label: String) -> Bool {
        label == "0:00" || label == "00:00" || label == "0:00:00" || label == "00:00:00"
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
