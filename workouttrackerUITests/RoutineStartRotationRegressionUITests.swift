import XCTest

final class RoutineStartRotationRegressionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func test_homeShell_scheduleSeededRoutine_openCalendar_startThenRotateImmediately_staysOnSessionScreen() {
        let app = UITestLaunch.app(
            start: "home",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_LINKED_FLOW": "1"]
        )
        app.launch()

        let routinesTile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Routines"))
            .firstMatch

        if !routinesTile.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "RoutineStartRotation_HomeRoutinesTileMissing")
        }
        XCTAssertTrue(routinesTile.exists, "Expected Home screen to expose the Routines tile.")
        XCTAssertTrue(routinesTile.isHittable, "Expected Routines tile to be tappable without scrolling.")
        routinesTile.tap()

        let routineTitle = app.staticTexts["UITest — Linked Main"]
        if !routineTitle.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "RoutineStartRotation_SeededRoutineMissing")
        }
        XCTAssertTrue(
            routineTitle.exists,
            "Expected linked-flow seed to expose routine 'UITest — Linked Main' on the Routines screen."
        )

        let scheduleAction = rowButton(
            identifiedBy: "calendar.badge.plus",
            nearRoutineTitle: "UITest — Linked Main",
            in: app
        )
        if !waitForHittable(scheduleAction, timeout: t(4)) {
            attachUITestDebug(app, name: "RoutineStartRotation_ScheduleActionMissing")
        }
        XCTAssertTrue(scheduleAction.exists, "Expected a schedule action next to 'UITest — Linked Main'.")
        XCTAssertTrue(scheduleAction.isHittable, "Expected seeded routine schedule action to be hittable.")
        scheduleAction.tap()

        let openCalendar = app.buttons["Open Calendar"]
        if !openCalendar.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "RoutineStartRotation_OpenCalendarMissing")
        }
        XCTAssertTrue(openCalendar.exists, "Expected schedule confirmation to offer Open Calendar.")
        XCTAssertTrue(openCalendar.isHittable, "Expected Open Calendar to be tappable.")
        openCalendar.tap()

        let openWorkout = app.buttons["DayTimeline.WorkoutCard.DefaultAction"].firstMatch
        if !openWorkout.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "RoutineStartRotation_CalendarWorkoutCardMissing")
        }
        XCTAssertTrue(
            openWorkout.exists,
            "Expected the scheduled workout activity to be visible in Calendar."
        )
        XCTAssertTrue(
            openWorkout.isHittable,
            "Expected the scheduled workout activity action to be tappable without scrolling."
        )

        // Real repro path:
        // scheduled activity in calendar -> tap to start/open -> rotate immediately.
        openWorkout.tap()
        XCUIDevice.shared.orientation = .landscapeLeft

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "RoutineStartRotation_SessionMissingAfterRotate")
        }
        XCTAssertTrue(
            sessionScreen.exists,
            "Expected immediate rotation after starting the scheduled workout from Calendar to remain on WorkoutSession.Screen."
        )
    }

    // MARK: - Helpers

    private func rowButton(
        identifiedBy identifier: String,
        nearRoutineTitle title: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        let anchor = app.staticTexts[title]
        guard anchor.waitForExistence(timeout: t(2)) else {
            return app.buttons.matching(identifier: identifier).firstMatch
        }

        let candidates = app.buttons.matching(identifier: identifier).allElementsBoundByIndex.filter { button in
            button.exists &&
            !button.frame.isEmpty &&
            abs(button.frame.midY - anchor.frame.midY) < 40
        }

        if let nearest = candidates.min(by: { lhs, rhs in
            distance(from: lhs, to: anchor) < distance(from: rhs, to: anchor)
        }) {
            return nearest
        }

        return app.buttons.matching(identifier: identifier).firstMatch
    }

    private func distance(from element: XCUIElement, to anchor: XCUIElement) -> CGFloat {
        hypot(element.frame.midX - anchor.frame.midX, element.frame.midY - anchor.frame.midY)
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if element.exists && element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return element.exists && element.isHittable
    }
}
