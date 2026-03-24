import XCTest

final class RoutineLinkedFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = UITestLaunch.app(
            start: "session",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_LINKED_FLOW": "1"]
        )
        app.launch()

        startLinkedRoutineSessionIfNeeded(app)
        XCTAssertTrue(waitForCurrentSegment("warmUp", timeout: 10), "Expected linked workout flow to start in warm-up segment.")
    }

    func test_linkedRoutineFlow_skipWarmUp_completeMain_skipCoolDown() {
        XCTAssertTrue(waitForCurrentSegment("warmUp", timeout: 10), "Expected warm-up segment header at session start.")

        dismissSessionOverlaysIfVisible()

        let skipWarmUp = app.buttons["WorkoutSession.SkipSegmentButton"]
        XCTAssertTrue(skipWarmUp.waitForExistence(timeout: 10), "Expected skip action at the warm-up boundary.")
        tapSafely(skipWarmUp)

        XCTAssertTrue(
            waitForMainSegmentReady(timeout: 10),
            "Expected skipping warm-up to enter the main workout segment."
        )

        let actionableDoneToggle = doneToggleForActionableRow()
        if !actionableDoneToggle.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "LinkedFlow_MainDoneToggleMissing")
        }
        XCTAssertTrue(actionableDoneToggle.exists, "Expected current main workout set row to expose a completion toggle.")
        tapSafely(actionableDoneToggle)

        dismissSessionOverlaysIfVisible()

        XCTAssertTrue(
            advanceToCoolDownIfNeeded(timeout: 10),
            "Expected completing the main segment to enter cool-down."
        )

        dismissSessionOverlaysIfVisible()

        let skipCoolDown = app.buttons["WorkoutSession.SkipSegmentButton"]
        if !skipCoolDown.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "LinkedFlow_CoolDownSkipMissing")
        }
        XCTAssertTrue(skipCoolDown.exists, "Expected skip action at the cool-down boundary.")

        XCTAssertTrue(
            waitForHittable(skipCoolDown, timeout: 5),
            "Expected cool-down skip button to become hittable after the segment transition settles."
        )
        tapSafely(skipCoolDown)

        let notNow = app.buttons["SessionReflection.NotNow"]
        let started = Date()
        while Date().timeIntervalSince(started) < 12 {
            if notNow.exists { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.10))
        }

        if !notNow.exists {
            attachUITestDebug(app, name: "LinkedFlow_ReflectionMissingAfterSkipCoolDown")
        }
        XCTAssertTrue(notNow.exists, "Expected session completion to present reflection after skipping cool-down.")
        notNow.tap()

        let finishSummary = app.otherElements["WorkoutSession.FinishSummary"]
        if !finishSummary.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "LinkedFlow_FinishSummaryMissing")
        }
        XCTAssertTrue(finishSummary.exists, "Expected the linked session flow to remain on the finish summary screen.")

        XCTAssertTrue(
            waitForFinishSummarySegmentRow("warmUp", timeout: 8),
            "Expected warm-up segment row in finish summary."
        )
        XCTAssertTrue(
            waitForFinishSummarySegmentRow("main", timeout: 8),
            "Expected main segment row in finish summary."
        )
        XCTAssertTrue(
            waitForFinishSummarySegmentRow("coolDown", timeout: 8),
            "Expected cool-down segment row in finish summary."
        )
    }

    private func waitForFinishSummarySegmentRow(_ id: String, timeout: TimeInterval) -> Bool {
        let row = identifiedElement("WorkoutSession.FinishSummary.Segment.\(id)")
        if row.waitForExistence(timeout: 1.5) { return true }

        let summary = identifiedElement("WorkoutSession.FinishSummary")
        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            if row.exists { return true }

            if summary.exists {
                summary.swipeUp()
            } else {
                app.swipeUp()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        return row.exists
    }
    
    private func dismissSessionOverlaysIfVisible() {
        let dismissCoach = app.buttons["Dismiss coach suggestion"]
        if dismissCoach.exists {
            tapSafely(dismissCoach)
        }

        let finishRest = app.buttons["RestTimerView.FinishButton"]
        if finishRest.exists {
            tapSafely(finishRest)
        }
    }

    private func isRestTimerOverlayVisible() -> Bool {
        let extendButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "RestTimerControlsView.Extend")
        )
        if extendButtons.count > 0 { return true }

        return app.buttons["WorkoutSession.ContinueButton"].exists && app.staticTexts["Rest"].exists
    }

    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if element.exists && element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return element.exists && element.isHittable
    }

    // MARK: - Session bootstrap

    private func startLinkedRoutineSessionIfNeeded(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if waitForCurrentSegment("warmUp", timeout: 8.0) { return }

        attachUITestDebug(app, name: "LinkedSessionRouteBootstrapFailed", file: file, line: line)
        XCTFail(
            """
            Expected UITESTS_START=session with UITESTS_LINKED_FLOW=1 to bootstrap into a seeded linked-routine session.
            The UITestHost session route did not reach the warm-up segment.
            """,
            file: file,
            line: line
        )
    }

    // MARK: - Segment waits

    private func waitForCurrentSegment(_ kindRaw: String, timeout: TimeInterval) -> Bool {
        let target = app.otherElements["SessionSegmentHeaderView.Current.\(kindRaw)"]
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if target.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return target.exists
    }

    private func waitForMainSegmentReady(timeout: TimeInterval) -> Bool {
        if waitForCurrentSegment("main", timeout: min(3, timeout)) {
            return true
        }

        let mainExerciseTitle = app.staticTexts["UITest Main Bench"]
        let actionableRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if mainExerciseTitle.exists && actionableRow.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return mainExerciseTitle.exists && actionableRow.exists
    }

    private func advanceToCoolDownIfNeeded(timeout: TimeInterval) -> Bool {
        if waitForCurrentSegment("coolDown", timeout: min(2, timeout)) {
            return true
        }

        let continueButton = app.buttons["WorkoutSession.ContinueButton"]
        if continueButton.waitForExistence(timeout: min(3, timeout)) {
            tapSafely(continueButton)
        }

        if waitForCurrentSegment("coolDown", timeout: min(4, timeout)) {
            return true
        }

        let coolDownTitle = app.staticTexts["UITest Cool-down Press"]
        let skipButton = app.buttons["WorkoutSession.SkipSegmentButton"]
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if coolDownTitle.exists && skipButton.exists && skipButton.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return coolDownTitle.exists && skipButton.exists && skipButton.isHittable
    }

    private func waitForSessionScreenToDisappear(timeout: TimeInterval) -> Bool {
        let screen = app.otherElements["WorkoutSession.Screen"]
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if !screen.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return !screen.exists
    }

    // MARK: - Set row identification

    private var doneTogglePredicate: NSPredicate {
        NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
            "WorkoutSetEditorRow.",
            ".DoneToggle"
        )
    }

    private func doneToggleForActionableRow() -> XCUIElement {
        let actionableRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if actionableRow.waitForExistence(timeout: 5) {
            let buttons = actionableRow.buttons.matching(doneTogglePredicate)
            if buttons.count > 0 { return buttons.firstMatch }

            let otherElements = actionableRow.otherElements.matching(doneTogglePredicate)
            if otherElements.count > 0 { return otherElements.firstMatch }
        }

        return firstVisibleDoneToggle(in: app)
    }

    private func firstVisibleDoneToggle(in app: XCUIApplication) -> XCUIElement {
        let buttons = app.buttons.matching(doneTogglePredicate).allElementsBoundByIndex
        if let hittable = buttons.first(where: { $0.exists && $0.isHittable }) {
            return hittable
        }
        if let first = buttons.first {
            return first
        }

        let otherElements = app.otherElements.matching(doneTogglePredicate).allElementsBoundByIndex
        if let hittable = otherElements.first(where: { $0.exists && $0.isHittable }) {
            return hittable
        }
        if let first = otherElements.first {
            return first
        }

        return app.buttons.matching(doneTogglePredicate).firstMatch
    }
    
    private func identifiedElement(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: id)
            .firstMatch
    }
}
