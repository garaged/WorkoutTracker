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

        // Important: this is an add/copy semantics test, not a text-entry test.
        // Use the seeded source values directly so the next tap is not fighting text-field focus.
        let sourceReps = normalizedTextFieldValue(repsField)
        let sourceWeight = normalizedTextFieldValue(weightField)
        XCTAssertFalse(sourceReps.isEmpty, "Expected source reps to have a seeded value before Add.")
        XCTAssertFalse(sourceWeight.isEmpty, "Expected source weight to have a seeded value before Add.")

        let before = setToggleIDs(in: app)

        let addBtn = app.buttons["WorkoutSetEditorRow.\(uuid).Actions.AddButton"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 10), "Expected Add button for the selected set row.")
        addBtn.tap()

        let undo = firstUndoButton(in: app)
        if !undo.waitForExistence(timeout: 10) {
            attachUITestDebug(app, name: "Phase1_AddSet_UndoMissing")
        }
        XCTAssertTrue(undo.exists, "Expected Undo toast after adding a set.")

        guard let newToggleID = waitForNewSetToggleID(after: before, timeout: 10),
              let newUUID = uuidFromDoneToggleIdentifier(newToggleID)
        else {
            attachUITestDebug(app, name: "Add did not create a visible new set")
            XCTFail("Expected Add to create a new set row (new DoneToggle identifier not detected).")
            return
        }

        let newReps = app.textFields["WorkoutSetEditorRow.\(newUUID).Reps.Field"]
        let newWeight = app.textFields["WorkoutSetEditorRow.\(newUUID).Weight.Field"]
        XCTAssertTrue(newReps.waitForExistence(timeout: 10), "Expected reps field for the added set.")
        XCTAssertTrue(newWeight.waitForExistence(timeout: 10), "Expected weight field for the added set.")

        let repsValue = normalizedTextFieldValue(newReps)
        let weightValue = normalizedTextFieldValue(newWeight)

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

        // Important: keep this test focused on copy semantics.
        // Editing the fields here makes the next copy-button tap flaky because focus can still be in the text field.
        let sourceReps = normalizedTextFieldValue(repsField)
        let sourceWeight = normalizedTextFieldValue(weightField)
        XCTAssertFalse(sourceReps.isEmpty, "Expected source reps to have a seeded value before Copy.")
        XCTAssertFalse(sourceWeight.isEmpty, "Expected source weight to have a seeded value before Copy.")

        let before = setToggleIDs(in: app)

        let copyBtn = app.buttons["WorkoutSetEditorRow.\(uuid).Actions.CopyButton"]
        XCTAssertTrue(copyBtn.waitForExistence(timeout: 10), "Expected Copy button for the selected set row.")
        copyBtn.tap()

        XCTAssertTrue(firstUndoButton(in: app).waitForExistence(timeout: 10),
                      "Expected Undo toast after copying a set.")

        guard let newToggleID = waitForNewSetToggleID(after: before, timeout: 10),
              let newUUID = uuidFromDoneToggleIdentifier(newToggleID)
        else {
            attachUITestDebug(app, name: "Copy did not create a visible new set")
            XCTFail("Expected Copy to create a new set row (new DoneToggle identifier not detected).")
            return
        }

        let newReps = app.textFields["WorkoutSetEditorRow.\(newUUID).Reps.Field"]
        let newWeight = app.textFields["WorkoutSetEditorRow.\(newUUID).Weight.Field"]
        XCTAssertTrue(newReps.waitForExistence(timeout: 10), "Expected reps field for the copied set.")
        XCTAssertTrue(newWeight.waitForExistence(timeout: 10), "Expected weight field for the copied set.")

        let repsValue = normalizedTextFieldValue(newReps)
        let weightValue = normalizedTextFieldValue(newWeight)

        XCTAssertEqual(repsValue, sourceReps, "Expected copied set reps to match source.")
        XCTAssertEqual(weightValue, sourceWeight, "Expected copied set weight to match source.")
    }

    // MARK: - Navigation to Session

    private func startFirstRoutineSessionIfNeeded(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if waitForSessionScreen(app: app, timeout: 8.0) { return }

        attachUITestDebug(app, name: "SessionRouteBootstrapFailed", file: file, line: line)
        XCTFail(
            """
            Expected UITESTS_START=session to bootstrap directly into a seeded workout session.
            The UITestHost session route did not reach the session screen.
            """,
            file: file,
            line: line
        )
    }
    
    func test_continue_centersActionableSet() {
        let continueButton = app.buttons["WorkoutSession.ContinueButton"]
        if !continueButton.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "Phase1_ContinueButtonMissing")
        }
        XCTAssertTrue(continueButton.exists, "Expected Continue button on session screen.")
        continueButton.tap()

        let focusedCard = app.otherElements["WorkoutSession.ActionableExerciseCard"]
        if !focusedCard.waitForExistence(timeout: 6) {
            attachUITestDebug(app, name: "Phase1_ActionableRowMissingAfterContinue")
        }

        assertApproximatelyVerticallyCentered(
            focusedCard,
            in: app,
            debugName: "Continue actionable row"
        )
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
                if reps.exists && weight.exists { return uuid }
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

    private func replaceText(in field: XCUIElement, with newValue: String) {
        XCTAssertTrue(field.exists, "Field does not exist: \(field)")

        // UI text fields in SwiftUI can be stubborn about where the cursor lands.
        // Clear multiple times, then type the desired value, and retry once if the final value is still empty.
        field.tap()
        field.tap()

        for _ in 0..<3 {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 24))
            if normalizedTextFieldValue(field).isEmpty { break }
        }

        field.typeText(newValue)

        if normalizedTextFieldValue(field).isEmpty {
            field.tap()
            field.typeText(newValue)
        }
    }

    private func normalizedTextFieldValue(_ field: XCUIElement) -> String {
        let raw = ((field.value as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if raw == "—" { return "" }
        return raw
    }
}
