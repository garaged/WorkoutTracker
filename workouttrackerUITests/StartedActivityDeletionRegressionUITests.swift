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

        // Home should initially show the seeded in-progress session reminder.
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

        // Navigate to Calendar through the same shell users use.
        let calendarTile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Calendar"))
            .firstMatch

        if !calendarTile.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_CalendarTileMissing")
        }
        XCTAssertTrue(calendarTile.exists, "Expected Home to expose the Calendar tile.")
        XCTAssertTrue(calendarTile.isHittable, "Expected Calendar tile to be tappable without scrolling.")
        calendarTile.tap()

        // The scroll seed provides exactly one workout activity on today's timeline.
        let activitiesCount = app.staticTexts["DayTimeline.Debug.ActivitiesCount"]
        let workoutsCount = app.staticTexts["DayTimeline.Debug.WorkoutsCount"]

        if !activitiesCount.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_TimelineDebugMissing")
        }
        XCTAssertTrue(activitiesCount.exists, "Expected timeline debug counts in UI tests.")
        XCTAssertEqual(activitiesCount.label, "Activities: 1")
        XCTAssertEqual(workoutsCount.label, "Workouts: 1")

        let workoutCard = workoutCardButton(titled: "UITest — Active Scroll", in: app)
        if !workoutCard.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_WorkoutCardMissing")
        }
        XCTAssertTrue(workoutCard.exists, "Expected the seeded workout card on Calendar.")

        openWorkoutActionsUsingMenu(for: "UITest — Active Scroll", in: app)

        let deleteButton = app.buttons["Delete"]
        if !deleteButton.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_DeleteActionMissing")
        }
        XCTAssertTrue(deleteButton.exists, "Expected Delete action for the started workout activity.")
        tapSafely(deleteButton)

        // Calendar should now be empty because the only activity was deleted.
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

        // Regression assertion:
        // deleting the started activity must also retire the active-session reminder.
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

    private func workoutCardButton(titled title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND label == %@",
                "DayTimeline.WorkoutCard.DefaultAction",
                title
            )
        ).firstMatch
    }

    private func openWorkoutActionsUsingMenu(for title: String, in app: XCUIApplication) {
        let workoutCard = workoutCardButton(titled: title, in: app)
        XCTAssertTrue(workoutCard.waitForExistence(timeout: t(4)), "Expected workout card before opening actions.")

        let menuHandle = moreActionsHandle(nearWorkoutTitle: title, in: app)
        if !menuHandle.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "StartedDeleteRegression_MenuHandleMissing")
        }
        XCTAssertTrue(menuHandle.exists, "Expected workout actions menu handle for the seeded workout card.")
        XCTAssertTrue(menuHandle.isHittable, "Expected workout actions menu handle to be tappable.")
        tapSafely(menuHandle)

        if app.buttons["Delete"].waitForExistence(timeout: t(3)) {
            return
        }

        attachUITestDebug(app, name: "StartedDeleteRegression_WorkoutActionsDidNotOpen")
        XCTFail("Expected tapping the workout card menu handle to open the workout actions dialog.")
    }

    private func moreActionsHandle(nearWorkoutTitle title: String, in app: XCUIApplication) -> XCUIElement {
        let anchor = app.staticTexts[title]
        XCTAssertTrue(anchor.waitForExistence(timeout: t(4)), "Expected workout title '\(title)' on Calendar.")

        let candidates = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Activity actions (drag to resize)"))
            .allElementsBoundByIndex
            .filter { $0.exists && !$0.frame.isEmpty }

        if let nearest = candidates.min(by: { score($0, anchor: anchor) < score($1, anchor: anchor) }) {
            return nearest
        }

        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Activity actions (drag to resize)"))
            .firstMatch
    }

    private func score(_ element: XCUIElement, anchor: XCUIElement) -> CGFloat {
        let vertical = abs(element.frame.midY - anchor.frame.midY)
        let horizontal = abs(element.frame.midX - anchor.frame.midX)
        return vertical * 4 + horizontal
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

        // Fallback for default iOS back-swipe behavior.
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
