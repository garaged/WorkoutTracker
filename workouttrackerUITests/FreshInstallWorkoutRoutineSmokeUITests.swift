import XCTest

// File: workouttrackerUITests/FreshInstallWorkoutRoutineSmokeUITests.swift
//
// Regression coverage:
// 1) Fresh install path: creating the *first* Workout-kind activity must not save an empty routine.
// 2) Compact iPhone layout: cardio-style rows (time + distance) must not clip the title or side columns.

final class FreshInstallWorkoutRoutineSmokeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_freshInstall_firstWorkoutActivity_startsNonEmptySession_withoutTouchingRoutinePicker() {
        app = UITestLaunch.app(start: "calendar", reset: true, seed: true)
        app.launch()

        let initialActivityCount = timelineActivityCount(in: app)

        XCTAssertTrue(tapNewActivityButton(app), "Expected to find/tap New Activity button")
        XCTAssertTrue(app.navigationBars["New Activity"].waitForExistence(timeout: t(6)), "Expected New Activity sheet")

        let title = "UITest — Fresh Workout"
        let titleField = app.el("activityEditor.titleField")
        XCTAssertTrue(titleField.waitForExistence(timeout: t(6)), "Expected activity title field")
        replaceText(in: titleField, with: title)

        XCTAssertTrue(ensureWorkoutKindSelected(app), "Expected Workout kind to be selected")

        let save = app.el("activityEditor.saveButton")
        XCTAssertTrue(save.waitForExistence(timeout: t(4)), "Expected Save button")
        tapSafely(save)

        XCTAssertTrue(
            waitForTimelineToReflectNewActivity(in: app, previousCount: initialActivityCount, timeout: t(12)),
            "Expected timeline to dismiss the editor and include the new activity"
        )

        startSessionFromTimelineBlock(named: title, in: app)

        XCTAssertTrue(
            waitForAnySetRow(in: app, timeout: t(12)),
            "Expected a non-empty workout session (at least one set row)"
        )
    }

    func test_starterCardioRoutine_compactLayout_doesNotClipTitleOrSideColumns() {
        app = UITestLaunch.app(start: "calendar", reset: true, seed: true)
        app.launch()

        startSessionFromTimelineBlock(named: "UITest — Seeded Starter Cardio", in: app)

        XCTAssertTrue(waitForAnySetRow(in: app, timeout: t(12)), "Expected to start a seeded cardio workout session")

        let runningTitle = app.staticTexts.matching(NSPredicate(format: "label == %@", "Running")).firstMatch
        XCTAssertTrue(runningTitle.waitForExistence(timeout: t(8)), "Expected a Running exercise card title")

        let doneToggle = firstDoneToggle(in: app)
        XCTAssertTrue(doneToggle.waitForExistence(timeout: t(8)), "Expected at least one set row done toggle")

        assertWithinHorizontalBounds(runningTitle, in: app, name: "Running title")
        assertWithinHorizontalBounds(doneToggle, in: app, name: "Done toggle")
        XCTAssertTrue(doneToggle.isHittable, "Expected done toggle to be hittable (not clipped)")
    }

    // MARK: - Helpers

    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()

        if let existingText = field.value as? String, !existingText.isEmpty {
            let deleteSequence = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingText.count)
            field.typeText(deleteSequence)
        }

        field.typeText(text)
    }

    private func any(_ app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func cellByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func staticByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func buttonByLabel(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func waitAny(_ candidates: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for c in candidates where c.exists { return c }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        for c in candidates {
            if c.waitForExistence(timeout: 0.5) { return c }
        }
        return nil
    }

    private func swipeUpInSheet(_ app: XCUIApplication) {
        let sv = app.scrollViews.firstMatch
        if sv.exists { sv.swipeUp() }
        else { app.swipeUp() }
    }

    private func swipeScrollableUp(_ app: XCUIApplication) {
        if app.tables.firstMatch.exists { app.tables.firstMatch.swipeUp(); return }
        if app.collectionViews.firstMatch.exists { app.collectionViews.firstMatch.swipeUp(); return }
        if app.scrollViews.firstMatch.exists { app.scrollViews.firstMatch.swipeUp(); return }
        app.swipeUp()
    }

    private func swipeScrollableDown(_ app: XCUIApplication) {
        if app.tables.firstMatch.exists { app.tables.firstMatch.swipeDown(); return }
        if app.collectionViews.firstMatch.exists { app.collectionViews.firstMatch.swipeDown(); return }
        if app.scrollViews.firstMatch.exists { app.scrollViews.firstMatch.swipeDown(); return }
        app.swipeDown()
    }

    @discardableResult
    private func ensureWorkoutKindSelected(_ app: XCUIApplication) -> Bool {
        // Prefer the explicit UITest hook (added in ActivityEditorSheet).
        // This avoids brittle .menu Picker interactions in SwiftUI Forms.
        let hook = app.el("activityEditor.uitestSetWorkoutKind")
        if hook.waitForExistence(timeout: t(1.5)) {
            tapSafely(hook)

            let routinePicker = app.el("activityEditor.routinePicker")
            if routinePicker.waitForExistence(timeout: t(2.5)) { return true }

            // If routines are unexpectedly missing, capture debug so we can see the empty state.
            if app.el("activityEditor.routineEmptyState").exists {
                attachUITestDebug(app, name: "FreshInstallWorkout_RoutineEmptyAfterSeed")
            } else {
                attachUITestDebug(app, name: "FreshInstallWorkout_RoutinePickerMissing")
            }
            return false
        }

        let routinePicker = app.el("activityEditor.routinePicker")
        if routinePicker.waitForExistence(timeout: t(1.5)) { return true }

        let typeControlCandidates: [XCUIElement] = [
            app.el("activityEditor.typePicker"),
            app.segmentedControls.buttons["Workout"],
            cellByLabel(app, contains: "Type"),
            cellByLabel(app, contains: "Kind"),
            staticByLabel(app, contains: "Type"),
            staticByLabel(app, contains: "Kind")
        ]

        if let typeControl = waitAny(typeControlCandidates, timeout: t(4)) {
            tapTypeControl(typeControl, in: app)
        }

        let workoutChoiceCandidates: [XCUIElement] = [
            app.segmentedControls.buttons["Workout"],
            app.buttons["Workout"],
            app.staticTexts["Workout"],
            buttonByLabel(app, contains: "Workout"),
            staticByLabel(app, contains: "Workout")
        ]

        if let workoutChoice = waitAny(workoutChoiceCandidates, timeout: t(2.5)) {
            tapSafely(workoutChoice)
        }

        if app.buttons["Done"].exists { tapSafely(app.buttons["Done"]) }

        if routinePicker.waitForExistence(timeout: t(2.5)) { return true }

        for _ in 0..<8 {
            swipeUpInSheet(app)
            if routinePicker.exists { return true }
        }

        attachUITestDebug(app, name: "FreshInstallWorkout_RoutinePickerMissing")
        return false
    }

    private func tapTypeControl(_ typeControl: XCUIElement, in app: XCUIApplication) {
        if typeControl.isHittable {
            typeControl.tap()
            return
        }

        let innerButton = typeControl.descendants(matching: .button).firstMatch
        if innerButton.waitForExistence(timeout: t(1)) {
            innerButton.tap()
            return
        }

        typeControl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func startSessionFromTimelineBlock(named title: String, in app: XCUIApplication) {
        let blockTitle = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier == %@ AND label == %@",
                    "DayTimeline.WorkoutCard.DefaultAction",
                    title
                )
            )
            .firstMatch

        if !blockTitle.waitForExistence(timeout: t(3)) {
            for _ in 0..<12 {
                swipeScrollableUp(app)
                if blockTitle.exists { break }
            }
            if !blockTitle.exists {
                for _ in 0..<12 {
                    swipeScrollableDown(app)
                    if blockTitle.exists { break }
                }
            }
        }

        if !blockTitle.exists {
            attachUITestDebug(app, name: "FreshInstallWorkout_BlockNotFound")
            XCTFail("Expected timeline to show the new activity block")
            return
        }

        func nearestAction(identifier: String, to anchor: XCUIElement) -> XCUIElement {
            let candidates = app.buttons.matching(identifier: identifier).allElementsBoundByIndex.filter { button in
                button.exists &&
                !button.frame.isEmpty &&
                abs(button.frame.midY - anchor.frame.midY) < 80 &&
                abs(button.frame.midX - anchor.frame.midX) < 220
            }

            if let nearest = candidates.min(by: { lhs, rhs in
                let ld = hypot(lhs.frame.midX - anchor.frame.midX, lhs.frame.midY - anchor.frame.midY)
                let rd = hypot(rhs.frame.midX - anchor.frame.midX, rhs.frame.midY - anchor.frame.midY)
                return ld < rd
            }) {
                return nearest
            }

            return app.buttons.matching(identifier: identifier).firstMatch
        }

        func waitForSessionScreen() -> Bool {
            any(app, id: "WorkoutSession.Screen").waitForExistence(timeout: t(6))
        }

        func confirmLaunchSheetStartIfPresent() -> Bool {
            let launchSheet = app.sheets.firstMatch
            guard launchSheet.waitForExistence(timeout: t(1.5)) else { return false }
            let startInSheet = launchSheet.buttons["Start"].firstMatch
            guard startInSheet.waitForExistence(timeout: t(2)) else { return false }
            startInSheet.tap()
            return waitForSessionScreen()
        }

        if blockTitle.exists {
            tapSafely(blockTitle)
            if waitForSessionScreen() || confirmLaunchSheetStartIfPresent() { return }
        }

        // Preferred path: tap the Start overlay that belongs to this exact card.
        let startOverlay = nearestAction(identifier: "DayTimeline.WorkoutOverlay.Start", to: blockTitle)
        if startOverlay.waitForExistence(timeout: t(1.5)) {
            tapSafely(startOverlay)
            if waitForSessionScreen() || confirmLaunchSheetStartIfPresent() { return }
        }

        // Fallback: tap the card default action, then accept the popover Start path if it appears.
        let defaultAction = nearestAction(identifier: "DayTimeline.WorkoutCard.DefaultAction", to: blockTitle)
        guard defaultAction.waitForExistence(timeout: t(1.5)) else {
            attachUITestDebug(app, name: "FreshInstallWorkout_DefaultActionMissing")
            XCTFail("Expected DayTimeline.WorkoutCard.DefaultAction near \(title).")
            return
        }

        if !defaultAction.isHittable {
            for _ in 0..<4 {
                if defaultAction.isHittable { break }
                if blockTitle.frame.maxY > app.frame.maxY - 120 {
                    swipeScrollableUp(app)
                } else if blockTitle.frame.minY < 120 {
                    swipeScrollableDown(app)
                } else {
                    swipeScrollableUp(app)
                }
            }
        }

        tapSafely(defaultAction)
        if confirmLaunchSheetStartIfPresent() { return }

        if !waitForSessionScreen() {
            attachUITestDebug(app, name: "FreshInstallWorkout_SessionDidNotOpen")
            XCTFail("Expected tapping \(title) to open WorkoutSession.Screen.")
        }
    }

    private func timelineActivityCount(in app: XCUIApplication) -> Int? {
        let countLabel = app.staticTexts["DayTimeline.Debug.ActivitiesCount"]
        guard countLabel.waitForExistence(timeout: t(6)) else { return nil }

        return parseTrailingCount(from: countLabel.label)
    }

    private func waitForTimelineToReflectNewActivity(
        in app: XCUIApplication,
        previousCount: Int?,
        timeout: TimeInterval
    ) -> Bool {
        let editorNav = app.navigationBars["New Activity"].firstMatch
        let countLabel = app.staticTexts["DayTimeline.Debug.ActivitiesCount"]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let editorDismissed = !editorNav.exists
            let updatedCount = parseTrailingCount(from: countLabel.label)
            let countAdvanced = previousCount == nil || (updatedCount.map { $0 > previousCount! } ?? false)

            if editorDismissed && countAdvanced {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        if editorNav.exists || countLabel.exists {
            attachUITestDebug(app, name: "FreshInstallWorkout_TimelineDidNotRefresh")
        }
        return false
    }

    private func parseTrailingCount(from label: String) -> Int? {
        let digits = label.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
        return digits.flatMap(Int.init)
    }

    private var doneTogglePredicate: NSPredicate {
        NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    "WorkoutSetEditorRow.", ".DoneToggle")
    }

    private func setToggleQuery(in app: XCUIApplication) -> XCUIElementQuery {
        let buttons = app.buttons.matching(doneTogglePredicate)
        if buttons.count > 0 { return buttons }

        let switches = app.switches.matching(doneTogglePredicate)
        if switches.count > 0 { return switches }

        return app.otherElements.matching(doneTogglePredicate)
    }

    private func firstDoneToggle(in app: XCUIApplication) -> XCUIElement {
        setToggleQuery(in: app).firstMatch
    }

    private func waitForAnySetRow(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if setToggleQuery(in: app).count > 0 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return setToggleQuery(in: app).count > 0
    }

    private func assertWithinHorizontalBounds(_ el: XCUIElement, in app: XCUIApplication, name: String,
                                              file: StaticString = #filePath, line: UInt = #line) {
        let eps: CGFloat = 1.0
        let w = app.frame.width
        let minX = el.frame.minX
        let maxX = el.frame.maxX

        if !(minX >= -eps && maxX <= w + eps) {
            attachUITestDebug(app, name: "CardioLayout_\(name.replacingOccurrences(of: " ", with: "_"))_OutOfBounds")
        }

        XCTAssertGreaterThanOrEqual(minX, -eps, "\(name) should not be clipped on the left", file: file, line: line)
        XCTAssertLessThanOrEqual(maxX, w + eps, "\(name) should not be clipped on the right", file: file, line: line)
    }
}
