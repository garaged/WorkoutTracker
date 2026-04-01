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

        XCTAssertTrue(
            revealCurrentSegmentBoundary("warmUp", timeout: 8),
            "Expected current warm-up boundary to become visible before skipping."
        )

        XCTAssertTrue(
            skipCurrentSegmentAndWaitTransition(from: "warmUp", to: "main", timeout: 10),
            "Expected skipping warm-up to enter the main workout segment."
        )

        let actionableDoneToggle = doneToggleForCurrentRow()
        if !actionableDoneToggle.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "LinkedFlow_MainDoneToggleMissing")
        }
        XCTAssertTrue(actionableDoneToggle.exists, "Expected current main workout set row to expose a completion toggle.")
        tapSafely(actionableDoneToggle)

        XCTAssertTrue(
            waitForMainCompletionTransition(afterTapping: actionableDoneToggle, timeout: 8),
            "Expected completing the current main set to update the row state or reveal the next-step controls."
        )

        dismissSessionOverlaysIfVisible()

        XCTAssertTrue(
            advanceToCoolDownIfNeeded(timeout: 10),
            "Expected completing the main segment to enter cool-down."
        )

        dismissSessionOverlaysIfVisible()

        let currentCoolDownHeader = app.otherElements["SessionSegmentHeaderView.Current.coolDown"]
        if !currentCoolDownHeader.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "LinkedFlow_CurrentCoolDownHeaderMissing")
        }
        XCTAssertTrue(currentCoolDownHeader.exists, "Expected current cool-down segment header after advancing past the main segment.")

        let skipCoolDown = skipButton(inCurrentSegment: "coolDown")
        if !skipCoolDown.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "LinkedFlow_CoolDownSkipMissing")
        }
        XCTAssertTrue(skipCoolDown.exists, "Expected skip action at the cool-down boundary.")

        XCTAssertTrue(
            waitForHittable(skipCoolDown, timeout: 5),
            "Expected cool-down skip button to become hittable after the segment transition settles."
        )
        tapSafely(skipCoolDown)

        let finishSummary = app.otherElements["WorkoutSession.FinishSummary"]
        let notNow = app.buttons["SessionReflection.NotNow"]

        let didReachCompletionSurface = waitForReflectionOrFinishSummary(timeout: 12)
        if !didReachCompletionSurface {
            attachUITestDebug(app, name: "LinkedFlow_CompletionMissing")
        }
        XCTAssertTrue(
            didReachCompletionSurface,
            "Expected session completion to present reflection or the finish summary after skipping cool-down."
        )

        if notNow.exists {
            notNow.tap()
        }

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
    
    private func revealCurrentSegmentBoundary(_ kind: String, timeout: TimeInterval) -> Bool {
        let header = app.otherElements["SessionSegmentHeaderView.Current.\(kind)"]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let skip = skipButton(inCurrentSegment: kind)

            if header.exists && skip.exists && skip.isHittable {
                return true
            }

            if let scrollView = app.scrollViews.allElementsBoundByIndex.first {
                scrollView.swipeDown()
            } else {
                app.swipeDown()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        return false
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

    private func waitForReflectionOrFinishSummary(timeout: TimeInterval) -> Bool {
        let notNow = app.buttons["SessionReflection.NotNow"]
        let finishSummary = app.otherElements["WorkoutSession.FinishSummary"]
        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            if notNow.exists || finishSummary.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.10))
        }

        return notNow.exists || finishSummary.exists
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
        let currentMainHeader = app.otherElements["SessionSegmentHeaderView.Current.main"]
        let currentWarmUpHeader = app.otherElements["SessionSegmentHeaderView.Current.warmUp"]
        let actionableRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            if currentMainHeader.exists && actionableRow.exists && !currentWarmUpHeader.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return currentMainHeader.exists && actionableRow.exists && !currentWarmUpHeader.exists
    }

    private func skipCurrentSegmentAndWaitTransition(from currentKind: String, to nextKind: String, timeout: TimeInterval) -> Bool {
        let currentHeader = app.otherElements["SessionSegmentHeaderView.Current.\(currentKind)"]
        let nextHeader = app.otherElements["SessionSegmentHeaderView.Current.\(nextKind)"]
        let deadline = Date().addingTimeInterval(timeout)
        var lastTapAt = Date.distantPast

        while Date() < deadline {
            if nextHeader.exists && !currentHeader.exists {
                return true
            }

            _ = revealCurrentSegmentBoundary(currentKind, timeout: 1.0)

            let skip = skipButton(inCurrentSegment: currentKind)
            if skip.exists && skip.isHittable && Date().timeIntervalSince(lastTapAt) > 0.6 {
                tapSafely(skip)
                lastTapAt = Date()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.10))
        }

        if !(nextHeader.exists && !currentHeader.exists) {
            attachUITestDebug(app, name: "LinkedFlow_\(currentKind)_To_\(nextKind)_TransitionMissing")
        }

        return nextHeader.exists && !currentHeader.exists
    }

    private func advanceToCoolDownIfNeeded(timeout: TimeInterval) -> Bool {
        if waitForCurrentCoolDownBoundary(timeout: min(2, timeout)) {
            return true
        }

        let continueButton = app.buttons["WorkoutSession.ContinueButton"]
        if continueButton.waitForExistence(timeout: min(3, timeout)) {
            tapSafely(continueButton)
        }

        if waitForCurrentCoolDownBoundary(timeout: timeout) {
            return true
        }

        attachUITestDebug(app, name: "LinkedFlow_CoolDownBoundaryNotReached")
        return false
    }

    private func waitForCurrentCoolDownBoundary(timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let header = app.otherElements["SessionSegmentHeaderView.Current.coolDown"]
            if header.exists {
                let skipButton = header.descendants(matching: .button)
                    .matching(identifier: "WorkoutSession.SkipSegmentButton")
                    .firstMatch
                if skipButton.exists && skipButton.isHittable {
                    return true
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return false
    }

    // MARK: - Set row identification

    private var doneTogglePredicate: NSPredicate {
        NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
            "WorkoutSetEditorRow.",
            ".DoneToggle"
        )
    }

    private func doneToggleForCurrentRow() -> XCUIElement {
        let actionableRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if actionableRow.waitForExistence(timeout: 5) {
            let buttons = actionableRow.buttons.matching(doneTogglePredicate)
            if buttons.count > 0 { return buttons.firstMatch }

            let otherElements = actionableRow.otherElements.matching(doneTogglePredicate)
            if otherElements.count > 0 { return otherElements.firstMatch }
        }

        attachUITestDebug(app, name: "LinkedFlow_ActionableRowMissing")
        return firstVisibleDoneToggle(in: app)
    }

    private func waitForMainCompletionTransition(afterTapping toggle: XCUIElement, timeout: TimeInterval) -> Bool {
        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            if waitForCurrentSegment("coolDown", timeout: 0.15) {
                return true
            }

            if toggle.exists && toggle.label.localizedCaseInsensitiveContains("incomplete") {
                return true
            }

            let currentMainHeader = app.otherElements["SessionSegmentHeaderView.Current.main"]
            if currentMainHeader.exists {
                let mainProgress = currentMainHeader.staticTexts["SessionSegmentHeaderView.Progress.main"]
                if mainProgress.exists && mainProgress.label == "1/1 sets" {
                    return true
                }
            }

            if isRestTimerOverlayVisible() {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.10))
        }

        return waitForCurrentSegment("coolDown", timeout: 0.15)
            || (toggle.exists && toggle.label.localizedCaseInsensitiveContains("incomplete"))
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

    private func skipButton(inCurrentSegment kindRaw: String) -> XCUIElement {
        let header = app.otherElements["SessionSegmentHeaderView.Current.\(kindRaw)"]
        return header.descendants(matching: .button)
            .matching(identifier: "WorkoutSession.SkipSegmentButton")
            .firstMatch
    }

    private func identifiedElement(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: id)
            .firstMatch
    }
}
