import XCTest

final class StartedActivityDeletionRegressionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func test_deletingStartedWorkoutActivity_removesHomeActiveSessionReminder() {
        let app = UITestLaunch.app(
            start: "home",
            reset: true,
            seed: false,
            extraEnv: ["UITESTS_ACTIVE_SESSIONS_SCROLL": "1"]
        )
        app.launch()

        let homeSection = app.el("Home.ActiveSessions.Section")
        if !homeSection.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_HomeSectionMissingBeforeDelete")
        }
        XCTAssertTrue(homeSection.exists, "Expected Home to show Active Sessions before deleting the started workout.")

        let homeResume = app.buttons["Home.ActiveSessions.Resume.Today"]
        if !homeResume.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_HomeResumeMissingBeforeDelete")
        }
        XCTAssertTrue(homeResume.exists, "Expected a Home Resume action for the seeded in-progress workout.")

        let calendarTile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Calendar"))
            .firstMatch

        if !calendarTile.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_CalendarTileMissing")
        }
        XCTAssertTrue(calendarTile.exists, "Expected Home to expose the Calendar tile.")
        XCTAssertTrue(calendarTile.isHittable, "Expected Calendar tile to be tappable without scrolling.")
        calendarTile.tap()

        let activitiesCount = app.staticTexts["DayTimeline.Debug.ActivitiesCount"]
        let workoutsCount = app.staticTexts["DayTimeline.Debug.WorkoutsCount"]

        if !activitiesCount.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_TimelineDebugMissing")
        }
        XCTAssertTrue(activitiesCount.exists, "Expected timeline debug counts in UI tests.")
        XCTAssertEqual(activitiesCount.label, "Activities: 1")
        XCTAssertEqual(workoutsCount.label, "Workouts: 1")

        openWorkoutActionsUsingMenu(for: "UITest — Active Scroll", in: app)

        let deleteButton = deleteAction(in: app)
        if !deleteButton.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_DeleteActionMissing")
        }
        XCTAssertTrue(deleteButton.exists, "Expected Delete action for the started workout activity.")
        tapSafely(deleteButton)

        if !waitForLabel(activitiesCount, toEqual: "Activities: 0", timeout: t(6)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_ActivitiesCountDidNotClear")
        }
        XCTAssertEqual(
            activitiesCount.label,
            "Activities: 0",
            "Expected deleting the started workout activity to remove it from Calendar."
        )

        if !waitForLabel(workoutsCount, toEqual: "Workouts: 0", timeout: t(6)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_WorkoutsCountDidNotClear")
        }
        XCTAssertEqual(
            workoutsCount.label,
            "Workouts: 0",
            "Expected deleting the started workout activity to remove the workout entry from Calendar."
        )

        navigateBackToHome(from: app)

        XCTAssertFalse(
            app.staticTexts["UITest — Active Scroll"].waitForExistence(timeout: t(2)),
            "Expected deleted started workout to disappear from the Home active-session reminder."
        )
        XCTAssertFalse(
            app.buttons["Home.ActiveSessions.Resume.Today"].exists,
            "Expected Home Resume action to disappear after deleting the started workout activity."
        )
        XCTAssertFalse(
            app.el("Home.ActiveSessions.Section").exists,
            "Expected Active Sessions section to disappear when the only started workout was deleted."
        )
    }

    // MARK: - Helpers

    private func openWorkoutActionsUsingMenu(for title: String, in app: XCUIApplication) {
        let titleLabel = app.staticTexts[title].firstMatch
        if !titleLabel.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_WorkoutTitleMissing")
        }
        XCTAssertTrue(titleLabel.exists, "Expected workout title '\(title)' on Calendar.")

        let titleCenter = titleLabel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        // The row menu hotspot is visually on the lower-right side of the card.
        // Since the row action identifier is not exposed here, tap geometry instead.
        let primaryTap = titleCenter.withOffset(CGVector(dx: 290, dy: 42))
        primaryTap.tap()

        if waitForDeleteAction(in: app) {
            return
        }

        let secondaryTap = titleCenter.withOffset(CGVector(dx: 250, dy: 28))
        secondaryTap.tap()

        if waitForDeleteAction(in: app) {
            return
        }

        let tertiaryTap = titleCenter.withOffset(CGVector(dx: 310, dy: 18))
        tertiaryTap.tap()

        if waitForDeleteAction(in: app) {
            return
        }

        attachUITestDebug(app, name: "StartedDeleteRegression_WorkoutActionsDidNotOpen")
        XCTFail("Expected workout actions to open from the calendar row menu handle.")
    }

    private func deleteAction(in app: XCUIApplication) -> XCUIElement {
        if app.sheets.buttons["Delete"].exists || app.sheets.buttons["Delete"].waitForExistence(timeout: t(1)) {
            return app.sheets.buttons["Delete"]
        }

        if app.alerts.buttons["Delete"].exists || app.alerts.buttons["Delete"].waitForExistence(timeout: t(1)) {
            return app.alerts.buttons["Delete"]
        }

        return app.buttons["Delete"]
    }

    private func waitForDeleteAction(in app: XCUIApplication) -> Bool {
        if app.sheets.buttons["Delete"].waitForExistence(timeout: t(2)) {
            return true
        }

        if app.alerts.buttons["Delete"].waitForExistence(timeout: t(2)) {
            return true
        }

        if app.buttons["Delete"].waitForExistence(timeout: t(2)) {
            return true
        }

        return false
    }

    private func navigateBackToHome(from app: XCUIApplication) {
        let explicitBackCandidates: [XCUIElement] = [
            app.navigationBars.buttons["Workout Tracker"],
            app.navigationBars.buttons["Home"]
        ]

        for button in explicitBackCandidates {
            if button.exists && button.isHittable {
                button.tap()
                if app.el("Home.ActiveSessions.Section").exists || app.staticTexts["Workout Tracker"].exists {
                    return
                }
            }
        }

        app.swipeRight()
    }

    private func waitForLabel(_ element: XCUIElement, toEqual expected: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.label == expected {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return element.exists && element.label == expected
    }

    private func tapSafely(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
