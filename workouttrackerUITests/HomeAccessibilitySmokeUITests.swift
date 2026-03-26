import XCTest
import UIKit

final class HomeAccessibilitySmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_homeActiveSessions_largeText_buttonsRemainHittable() {
        let app = UITestLaunch.app(
            start: "home",
            reset: true,
            seed: false,
            preferredContentSizeCategory: .accessibilityExtraExtraLarge,
            extraEnv: ["UITESTS_ACTIVE_SESSIONS": "1"]
        )
        app.launch()

        let settingsButton = app.buttons["settings.toolbarLink"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: t(4)), "Expected Settings button under large text.")
        XCTAssertTrue(settingsButton.isHittable, "Expected Settings button to remain hittable under large text.")

        let section = app.el("Home.ActiveSessions.Section")
        if !section.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "HomeAccessibility_SectionMissing")
        }
        XCTAssertTrue(section.exists, "Expected Home Active Sessions section under large text.")

        let todayTitle = app.staticTexts["UITest — Active Today"]
        XCTAssertTrue(todayTitle.waitForExistence(timeout: t(4)), "Expected today's active-session title under large text.")

        let todayResume = app.buttons["Home.ActiveSessions.Resume.Today"]
        XCTAssertTrue(todayResume.waitForExistence(timeout: t(4)), "Expected today's Resume button.")
        if !scrollUntilHittable(todayResume, in: app) {
            attachUITestDebug(app, name: "HomeAccessibility_TodayResumeNotHittable")
        }
        XCTAssertTrue(scrollUntilHittable(todayResume, in: app), "Expected today's Resume button to remain reachable under large text.")

        let previousDayFinish = app.buttons["Home.ActiveSessions.Finish.PreviousDay"]
        XCTAssertTrue(previousDayFinish.waitForExistence(timeout: t(4)), "Expected previous-day Finish now button.")
        if !scrollUntilHittable(previousDayFinish, in: app) {
            attachUITestDebug(app, name: "HomeAccessibility_FinishNotHittable")
        }
        XCTAssertTrue(scrollUntilHittable(previousDayFinish, in: app), "Expected previous-day Finish now button to remain reachable under large text.")
    }

    @discardableResult
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 4) -> Bool {
        if element.isHittable { return true }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.isHittable { return true }
        }

        return element.isHittable
    }
}
