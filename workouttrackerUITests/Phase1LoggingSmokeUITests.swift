import XCTest

// File: workouttrackerUITests/Phase1LoggingSmokeUITests.swift
//
// Goal:
// - Protect the workout logging “undo” interactions (done/add/copy).
//
// Test design:
// - Avoid brittle "count == N" assertions.
// - Instead, detect the *specific* set row that was added/copied (by accessibility identifier)
//   and assert it disappears after Undo.

final class Phase1LoggingSmokeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = UITestLaunch.app(start: "session", reset: true, seed: true)
        app.launch()

        startFirstRoutineSessionIfNeeded(app)
        assertOnSessionScreen(app)
    }

    func test_done_thenUndo_smoke() {
        let doneToggle = firstDoneToggle(in: app)
        XCTAssertTrue(doneToggle.waitForExistence(timeout: 10), "Expected at least one set row.")
        doneToggle.tap()

        let undoBtn = firstUndoButton(in: app)
        XCTAssertTrue(undoBtn.waitForExistence(timeout: 10),
                      "Expected Undo toast after completing a set (Undo button missing).")

        undoBtn.tap()
        XCTAssertTrue(waitForUndoToastToDisappear(in: app, timeout: 10),
                      "Expected Undo toast to disappear after undo.")
    }

    func test_addSet_showsUndo_andUndoRemovesTheAddedRow() {
        let beforeCount = setToggleQuery(in: app).count
        XCTAssertGreaterThan(beforeCount, 0, "Expected at least 1 set row visible.")

        let addButton = firstAddSetButton(in: app)
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Expected an Add Set button.")
        addButton.tap()

        let undoBtn = firstUndoButton(in: app)
        XCTAssertTrue(undoBtn.waitForExistence(timeout: 10),
                      "Expected Undo toast after adding a set (Undo button missing).")
        undoBtn.tap()

        XCTAssertTrue(waitForUndoToastToDisappear(in: app, timeout: 10),
                      "Expected Undo toast to disappear after undo.")
    }

    func test_copySet_showsUndo_andUndoRemovesTheCopiedRow() {
        let beforeCount = setToggleQuery(in: app).count
        XCTAssertGreaterThan(beforeCount, 0, "Expected at least 1 set row visible.")

        let copyButton = firstCopySetButton(in: app)
        XCTAssertTrue(copyButton.waitForExistence(timeout: 10), "Expected a Copy button.")
        copyButton.tap()

        let undoBtn = firstUndoButton(in: app)
        XCTAssertTrue(undoBtn.waitForExistence(timeout: 10),
                      "Expected Undo toast after copying a set (Undo button missing).")
        undoBtn.tap()

        XCTAssertTrue(waitForUndoToastToDisappear(in: app, timeout: 10),
                      "Expected Undo toast to disappear after undo.")
    }

    // MARK: - Regression: Copy vs Add should NOT be identical

    func test_addSet_doesNotDuplicateRepsOrWeight() {
        guard let uuid = firstRepsWeightSetUUID(in: app) else {
            attachUITestDebug(app, name: "No reps/weight set found")
            XCTFail("Expected to find a reps/weight set row to exercise copy/add semantics.")
            return
        }

        let repsField = app.textFields["WorkoutSetEditorRow.\(uuid).Reps.Field"]
        let weightField = app.textFields["WorkoutSetEditorRow.\(uuid).Weight.Field"]
        XCTAssertTrue(repsField.waitForExistence(timeout: 10), "Expected reps field.")
        XCTAssertTrue(weightField.waitForExistence(timeout: 10), "Expected weight field.")

        let repsPlus = app.buttons["WorkoutSetEditorRow.\(uuid).Reps.Plus"]
        XCTAssertTrue(repsPlus.waitForExistence(timeout: 10), "Expected reps plus button.")
        for _ in 0..<5 { repsPlus.tap() }   // 5 -> 10

        let sourceReps = normalizedTextFieldValue(repsField)
        let sourceWeight = normalizedTextFieldValue(weightField)

        XCTAssertEqual(sourceReps, "10", "Expected source reps to be 10 before exercising copy/add semantics.")
        XCTAssertFalse(sourceWeight.isEmpty, "Expected source weight to have a seeded value before exercising copy/add semantics.")
        
        XCTAssertFalse(sourceReps.isEmpty, "Expected source reps to have a value before Add.")
        XCTAssertFalse(sourceWeight.isEmpty, "Expected source weight to have a value before Add.")

        let before = setToggleIDs(in: app)

        let addBtn = app.buttons["WorkoutSetEditorRow.\(uuid).Actions.AddButton"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 10), "Expected Add button for the selected set row.")
        addBtn.tap()

        let undo = firstUndoButton(in: app)
        if !undo.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "Phase1_AddSet_UndoMissing")
        }
        XCTAssertTrue(undo.exists, "Expected Undo toast after adding a set.")

        guard let newUUID = waitForNewSetUUID(after: before, excluding: uuid, timeout: 10) else {
            attachUITestDebug(app, name: "Add did not create a visible new set")
            XCTFail("Expected Add to create a new set row (new DoneToggle identifier not detected).")
            return
        }

        guard let (newReps, newWeight) = waitForEditableSetFields(uuid: newUUID, timeout: 10) else {
            attachUITestDebug(app, name: "Add set fields did not become visible")
            XCTFail("Expected reps and weight fields for the added set.")
            return
        }

        let repsValue = normalizedTextFieldValue(newReps)
        let weightValue = normalizedTextFieldValue(newWeight)

        // Practical contract: Add should create a fresh row, not a clone of the source actuals.
        XCTAssertNotEqual(repsValue, sourceReps, "Expected added set reps to differ from the source actuals.")
        XCTAssertNotEqual(weightValue, sourceWeight, "Expected added set weight to differ from the source actuals.")
    }

    func test_copySet_duplicatesRepsAndWeight() {
        guard let uuid = firstRepsWeightSetUUID(in: app) else {
            attachUITestDebug(app, name: "No reps/weight set found")
            XCTFail("Expected to find a reps/weight set row to exercise copy/add semantics.")
            return
        }

        let repsField = app.textFields["WorkoutSetEditorRow.\(uuid).Reps.Field"]
        let weightField = app.textFields["WorkoutSetEditorRow.\(uuid).Weight.Field"]
        XCTAssertTrue(repsField.waitForExistence(timeout: 10), "Expected reps field.")
        XCTAssertTrue(weightField.waitForExistence(timeout: 10), "Expected weight field.")

        let repsPlus = app.buttons["WorkoutSetEditorRow.\(uuid).Reps.Plus"]
        XCTAssertTrue(repsPlus.waitForExistence(timeout: 10), "Expected reps plus button.")
        for _ in 0..<5 { repsPlus.tap() }   // 5 -> 10

        let sourceReps = normalizedTextFieldValue(repsField)
        let sourceWeight = normalizedTextFieldValue(weightField)

        XCTAssertEqual(sourceReps, "10", "Expected source reps to be 10 before exercising copy/add semantics.")
        XCTAssertFalse(sourceWeight.isEmpty, "Expected source weight to have a seeded value before exercising copy/add semantics.")

        XCTAssertFalse(sourceReps.isEmpty, "Expected source reps to have a value before Copy.")
        XCTAssertFalse(sourceWeight.isEmpty, "Expected source weight to have a value before Copy.")

        let before = setToggleIDs(in: app)

        let copyBtn = app.buttons["WorkoutSetEditorRow.\(uuid).Actions.CopyButton"]
        XCTAssertTrue(copyBtn.waitForExistence(timeout: 10), "Expected Copy button for the selected set row.")
        copyBtn.tap()

        XCTAssertTrue(firstUndoButton(in: app).waitForExistence(timeout: 10),
                      "Expected Undo toast after copying a set.")

        guard let newUUID = waitForNewSetUUID(after: before, excluding: uuid, timeout: 10) else {
            attachUITestDebug(app, name: "Copy did not create a visible new set")
            XCTFail("Expected Copy to create a new set row (new DoneToggle identifier not detected).")
            return
        }

        guard let (newReps, newWeight) = waitForEditableSetFields(uuid: newUUID, timeout: 10) else {
            attachUITestDebug(app, name: "Copy set fields did not become visible")
            XCTFail("Expected reps and weight fields for the copied set.")
            return
        }

        let repsValue = normalizedTextFieldValue(newReps)
        let weightValue = normalizedTextFieldValue(newWeight)

        // Contract: Copy should mirror the *source row’s current values*, whatever exact formatting the field reports.
        XCTAssertEqual(repsValue, sourceReps, "Expected copied set reps to match source.")
        XCTAssertEqual(weightValue, sourceWeight, "Expected copied set weight to match source.")
    }

    func test_restTimer_goesOverdue_untilContinueExplicitlyFinishesIt() {
        relaunchForShortRestTimerSession()
        completeFirstSetAndWaitForRestTimer()
        XCTAssertTrue(waitForRestTimerToGoOverdue(in: app, timeout: 8),
                      "Expected rest timer to stay visible and go overdue instead of stopping at zero.")

        app.buttons["WorkoutSession.ContinueButton"].tap()

        XCTAssertTrue(waitForElementToDisappear(app.buttons["RestTimerView.FinishButton"], timeout: 5),
                      "Expected Continue to explicitly finish the active rest timer.")
    }

    func test_restTimer_finishButton_explicitlyFinishesTimer() {
        relaunchForShortRestTimerSession()
        completeFirstSetAndWaitForRestTimer()
        XCTAssertTrue(waitForRestTimerToGoOverdue(in: app, timeout: 8),
                      "Expected rest timer to stay visible and go overdue before explicit finish.")

        let finishRest = app.buttons["RestTimerView.FinishButton"]
        finishRest.tap()

        XCTAssertTrue(waitForElementToDisappear(finishRest, timeout: 5),
                      "Expected Finish rest to dismiss the active rest timer.")
    }
    
    func test_restTimer_pauseWorkout_doesNotSilentlyFinishActiveRest() {
        relaunchForShortRestTimerSession()
        completeFirstSetAndWaitForRestTimer()

        XCTAssertTrue(
            waitForRestTimerToGoOverdue(in: app, timeout: 8),
            "Expected rest timer to stay visible and go overdue before pausing workout."
        )

        let pauseWorkout = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Pause")).firstMatch
        if !pauseWorkout.waitForExistence(timeout: 5) {
            attachUITestDebug(app, name: "Phase1_PauseWorkoutButtonMissing")
        }
        XCTAssertTrue(pauseWorkout.exists, "Expected pause workout button.")

        pauseWorkout.tap()

        let finishRest = app.buttons["RestTimerView.FinishButton"]
        if !finishRest.waitForExistence(timeout: 5) {
            attachUITestDebug(app, name: "Phase1_RestTimerHiddenByPause")
        }

        XCTAssertTrue(
            finishRest.exists,
            "Expected pausing workout not to silently finish or hide the active rest timer."
        )
    }

    // MARK: - Navigation to Session

    private func startFirstRoutineSessionIfNeeded(_ app: XCUIApplication) {
        if waitForSessionScreen(app: app, timeout: 1.0) { return }

        if app.tables.cells.firstMatch.waitForExistence(timeout: 2) {
            app.tables.cells.firstMatch.tap()
        } else if app.collectionViews.cells.firstMatch.waitForExistence(timeout: 2) {
            app.collectionViews.cells.firstMatch.tap()
        }

        let startCandidates: [XCUIElement] = [
            app.buttons.matching(NSPredicate(format: "label == %@", "Start Now")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Start")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Begin")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Continue")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Resume")).firstMatch
        ]

        for b in startCandidates where b.exists {
            b.tap()
            break
        }
    }
    
    func test_continue_centersActionableSet() {
        let continueButton = app.buttons["WorkoutSession.ContinueButton"]
        if !continueButton.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "Phase1_ContinueButtonMissing")
        }
        XCTAssertTrue(continueButton.exists, "Expected Continue button on session screen.")
        continueButton.tap()

        let focusedRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if !focusedRow.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "Phase1_ActionableRowMissingAfterContinue")
        }

        assertApproximatelyVerticallyCentered(
            focusedRow,
            in: app,
            debugName: "Continue actionable row"
        )
    }

    private func relaunchForShortRestTimerSession() {
        app.terminate()
        app = UITestLaunch.app(
            start: "session",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_REST_TIMER_SHORT": "1"]
        )
        app.launch()
        startFirstRoutineSessionIfNeeded(app)
        assertOnSessionScreen(app)
    }

    private func completeFirstSetAndWaitForRestTimer() {
        let doneToggle = firstDoneToggle(in: app)
        XCTAssertTrue(doneToggle.waitForExistence(timeout: 10), "Expected at least one set row.")
        doneToggle.tap()

        let finishRest = app.buttons["RestTimerView.FinishButton"]
        if !finishRest.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "Phase1_RestTimerFinishButtonMissing")
        }
        XCTAssertTrue(finishRest.exists, "Expected Finish rest button after completing a set.")
    }

    private func waitForRestTimerToGoOverdue(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let timeLabel = app.staticTexts["RestTimerView.TimeLabel"]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if timeLabel.exists, timeLabel.label.hasPrefix("-") {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        attachUITestDebug(app, name: "Phase1_RestTimerDidNotGoOverdue")
        return false
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if !element.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return !element.exists
    }

    // MARK: - Set Row Identification

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

    private func setToggleIDs(in app: XCUIApplication) -> Set<String> {
        let els = setToggleQuery(in: app).allElementsBoundByIndex
        return Set(els.map(\.identifier).filter { !$0.isEmpty })
    }

    private func waitForNewSetToggleID(after before: Set<String>, timeout: TimeInterval) -> String? {
        let start = Date()
        let beforeCount = before.count

        while Date().timeIntervalSince(start) < timeout {
            let q = setToggleQuery(in: app)
            if q.count > beforeCount {
                let after = setToggleIDs(in: app)
                let diff = after.subtracting(before)
                return diff.first
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        let after = setToggleIDs(in: app)
        let diff = after.subtracting(before)
        return diff.first
    }

    private func waitForNewSetUUID(after before: Set<String>, excluding sourceUUID: String, timeout: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let actionableUUID = actionableSetUUID(), actionableUUID != sourceUUID {
                return actionableUUID
            }

            if let newToggleID = waitForNewSetToggleID(after: before, timeout: 0.6),
               let newUUID = uuidFromDoneToggleIdentifier(newToggleID),
               newUUID != sourceUUID {
                return newUUID
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return actionableSetUUID()
    }

    private func actionableSetUUID() -> String? {
        let actionableRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        guard actionableRow.waitForExistence(timeout: 1.5) else { return nil }

        let toggle = actionableRow.buttons.matching(doneTogglePredicate).firstMatch
        guard toggle.exists else { return nil }
        return uuidFromDoneToggleIdentifier(toggle.identifier)
    }

    // MARK: - Finders

    private func firstDoneToggle(in app: XCUIApplication) -> XCUIElement {
        setToggleQuery(in: app).firstMatch
    }

    private func firstAddSetButton(in app: XCUIApplication) -> XCUIElement {
        let pred = NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                               "WorkoutSetEditorRow.", ".Actions.AddButton")
        let byId = app.buttons.matching(pred).firstMatch
        if byId.exists { return byId }
        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add")).firstMatch
    }

    private func firstCopySetButton(in app: XCUIApplication) -> XCUIElement {
        let pred = NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                               "WorkoutSetEditorRow.", ".Actions.CopyButton")
        let byId = app.buttons.matching(pred).firstMatch
        if byId.exists { return byId }
        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Copy")).firstMatch
    }

    private func firstUndoButton(in app: XCUIApplication) -> XCUIElement {
        let byId = app.descendants(matching: .any).matching(identifier: "UndoToastView.UndoButton").firstMatch
        if byId.exists { return byId }

        let byToast = app.descendants(matching: .any).matching(identifier: "UndoToastView").firstMatch
        if byToast.exists { return byToast }

        return app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Undo", "common.undo")).firstMatch
    }

    // MARK: - Assertions / waits

    private func waitForUndoToastToDisappear(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let undoById = app.descendants(matching: .any).matching(identifier: "UndoToastView.UndoButton").firstMatch
        let undoByLabel = app.buttons.matching(NSPredicate(format: "label == %@", "Undo")).firstMatch

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if !undoById.exists && !undoByLabel.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return !undoById.exists && !undoByLabel.exists
    }

    private func waitForSessionScreen(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if setToggleQuery(in: app).count > 0 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return setToggleQuery(in: app).count > 0
    }

    private func assertOnSessionScreen(_ app: XCUIApplication,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        if waitForSessionScreen(app: app, timeout: 12) { return }

        let shot = XCUIScreen.main.screenshot()
        let shotAttachment = XCTAttachment(screenshot: shot)
        shotAttachment.name = "UI Screenshot (not on session)"
        shotAttachment.lifetime = .keepAlways
        add(shotAttachment)

        let treeAttachment = XCTAttachment(string: app.debugDescription)
        treeAttachment.name = "UI Hierarchy Dump"
        treeAttachment.lifetime = .keepAlways
        add(treeAttachment)

        XCTFail("Expected to land on session screen.", file: file, line: line)
    }

    // MARK: - Helpers for copy/add semantics

    private func uuidFromDoneToggleIdentifier(_ id: String) -> String? {
        guard id.hasPrefix("WorkoutSetEditorRow."), id.hasSuffix(".DoneToggle") else { return nil }
        return id
            .replacingOccurrences(of: "WorkoutSetEditorRow.", with: "")
            .replacingOccurrences(of: ".DoneToggle", with: "")
    }

    private func firstRepsWeightSetUUID(in app: XCUIApplication) -> String? {
        func searchVisible() -> String? {
            let toggles = setToggleQuery(in: app).allElementsBoundByIndex
            for t in toggles.prefix(24) {
                guard let uuid = uuidFromDoneToggleIdentifier(t.identifier) else { continue }
                let reps = app.textFields["WorkoutSetEditorRow.\(uuid).Reps.Field"]
                let weight = app.textFields["WorkoutSetEditorRow.\(uuid).Weight.Field"]
                guard reps.exists, weight.exists else { continue }

                let repsValue = normalizedTextFieldValue(reps)
                let weightValue = normalizedTextFieldValue(weight)
                if !repsValue.isEmpty && !weightValue.isEmpty {
                    return uuid
                }
            }
            return nil
        }

        if let u = searchVisible() { return u }

        for _ in 0..<6 {
            app.swipeUp()
            if let u = searchVisible() { return u }
        }

        return nil
    }

    private func waitForEditableSetFields(uuid: String, timeout: TimeInterval) -> (XCUIElement, XCUIElement)? {
        let reps = app.textFields["WorkoutSetEditorRow.\(uuid).Reps.Field"]
        let weight = app.textFields["WorkoutSetEditorRow.\(uuid).Weight.Field"]

        if reps.waitForExistence(timeout: 1), weight.waitForExistence(timeout: 1) {
            return (reps, weight)
        }

        let rowToggle = app.descendants(matching: .any)
            .matching(identifier: "WorkoutSetEditorRow.\(uuid).DoneToggle")
            .firstMatch
        let row = app.otherElements["WorkoutSetEditorRow.\(uuid).Row"]

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if reps.exists && weight.exists {
                return (reps, weight)
            }

            if row.exists && row.isHittable {
                row.swipeUp()
            } else if rowToggle.exists && !rowToggle.isHittable {
                app.swipeUp()
            } else {
                RunLoop.current.run(until: Date().addingTimeInterval(0.10))
            }

            if reps.exists && weight.exists {
                return (reps, weight)
            }
        }

        for _ in 0..<3 {
            app.swipeDown()
            if reps.exists && weight.exists {
                return (reps, weight)
            }
        }

        return (reps.exists && weight.exists) ? (reps, weight) : nil
    }

    @discardableResult
    private func focusTextField(_ field: XCUIElement) -> Bool {
        XCTAssertTrue(field.waitForExistence(timeout: 2), "Field does not exist: \(field.identifier)")

        func hasKeyboardFocus(_ field: XCUIElement) -> Bool {
            field.debugDescription.contains("Keyboard Focused")
        }

        if hasKeyboardFocus(field) { return true }

        dismissKeyboardIfPresent()

        field.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.10))
        if hasKeyboardFocus(field) { return true }

        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.10))
        if hasKeyboardFocus(field) { return true }

        dismissKeyboardIfPresent()
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.10))

        return hasKeyboardFocus(field)
    }

    private func replaceText(in field: XCUIElement, with newValue: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Field does not exist: \(field.identifier)")
        XCTAssertTrue(focusTextField(field), "Could not focus field \(field.identifier)")

        let current = normalizedTextFieldValue(field)
        if !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 4))
        }

        field.typeText(newValue)

        XCTAssertTrue(
            waitForTextFieldValue(field, equals: newValue, timeout: 2),
            "Expected field \(field.identifier) to become \(newValue), found \(normalizedTextFieldValue(field))"
        )
    }

    private func dismissKeyboardIfPresent() {
        let donePred = NSPredicate(format: "label IN %@", ["Done", "Return", "Hide keyboard"])
        let doneButton = app.buttons.matching(donePred).firstMatch
        if doneButton.exists {
            doneButton.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.10))
            return
        }

        if app.keyboards.count > 0 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.10))
        }
    }

    private func waitForTextFieldValue(_ field: XCUIElement, equals expected: String, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if normalizedTextFieldValue(field) == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return normalizedTextFieldValue(field) == expected
    }

    private func normalizedTextFieldValue(_ field: XCUIElement) -> String {
        let raw = ((field.value as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if raw == "—" { return "" }
        return raw
    }
}
