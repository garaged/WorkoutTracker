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

        let skipWarmUp = app.buttons["WorkoutSession.SkipSegmentButton"]
        XCTAssertTrue(skipWarmUp.waitForExistence(timeout: 10), "Expected skip action at the warm-up boundary.")
        skipWarmUp.tap()

        XCTAssertTrue(waitForCurrentSegment("main", timeout: 10), "Expected skipping warm-up to enter the main workout segment.")

        let firstDone = firstDoneToggle(in: app)
        XCTAssertTrue(firstDone.waitForExistence(timeout: 10), "Expected main workout set row to be editable.")
        firstDone.tap()

        XCTAssertTrue(waitForCurrentSegment("coolDown", timeout: 10), "Expected completing the main segment to enter cool-down.")

        if app.buttons["Dismiss coach suggestion"].exists {
            app.buttons["Dismiss coach suggestion"].tap()
        }

        let restTimerToggle = app.buttons["WorkoutSession.RestTimerButton"]
        if restTimerToggle.exists {
            restTimerToggle.tap()   // hides the rest timer card if visible
        }
        
        let skipCoolDown = app.buttons["WorkoutSession.SkipSegmentButton"]
        XCTAssertTrue(skipCoolDown.waitForExistence(timeout: 10), "Expected skip action at the cool-down boundary.")

        if app.buttons["Dismiss coach suggestion"].exists {
            app.buttons["Dismiss coach suggestion"].tap()
        }

        XCTAssertTrue(skipCoolDown.waitForExistence(timeout: 5), "Expected cool-down skip button after dismissing overlays.")
        XCTAssertTrue(skipCoolDown.isHittable, "Expected cool-down skip button to be hittable after dismissing overlays.")

        skipCoolDown.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

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

        XCTAssertTrue(waitForSessionScreenToDisappear(timeout: 10), "Expected the linked session flow to finish after skipping cool-down.")
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
        NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    "WorkoutSetEditorRow.", ".DoneToggle")
    }

    private func firstDoneToggle(in app: XCUIApplication) -> XCUIElement {
        let buttons = app.buttons.matching(doneTogglePredicate)
        if buttons.count > 0 { return buttons.firstMatch }

        let switches = app.switches.matching(doneTogglePredicate)
        if switches.count > 0 { return switches.firstMatch }

        return app.otherElements.matching(doneTogglePredicate).firstMatch
    }
}
