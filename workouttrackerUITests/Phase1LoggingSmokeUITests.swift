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

        app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_SEED"] = "1"
        app.launchEnvironment["UITESTS_RESET"] = "1"
        app.launchEnvironment["UITESTS_START"] = "session"
        app.launchArguments = ["-uiTesting"]
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
        let before = setToggleIDs(in: app)
        XCTAssertGreaterThan(before.count, 0, "Expected at least 1 set row visible.")

        let addButton = firstAddSetButton(in: app)
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Expected an Add Set button.")
        addButton.tap()

        let addedID = waitForNewSetToggleID(after: before, timeout: 10)
        XCTAssertNotNil(addedID, "Expected a new set row to appear after Add.")
        guard let addedID else { return }

        let undoBtn = firstUndoButton(in: app)
        XCTAssertTrue(undoBtn.waitForExistence(timeout: 10),
                      "Expected Undo toast after adding a set (Undo button missing).")
        undoBtn.tap()

        XCTAssertTrue(waitForElementToDisappear(app: app, identifier: addedID, timeout: 12),
                      "Expected the added set row to disappear after Undo.")
    }

    func test_copySet_showsUndo_andUndoRemovesTheCopiedRow() {
        let before = setToggleIDs(in: app)
        XCTAssertGreaterThan(before.count, 0, "Expected at least 1 set row visible.")

        let copyButton = firstCopySetButton(in: app)
        XCTAssertTrue(copyButton.waitForExistence(timeout: 10), "Expected a Copy button.")
        copyButton.tap()

        let addedID = waitForNewSetToggleID(after: before, timeout: 10)
        XCTAssertNotNil(addedID, "Expected a new set row to appear after Copy.")
        guard let addedID else { return }

        let undoBtn = firstUndoButton(in: app)
        XCTAssertTrue(undoBtn.waitForExistence(timeout: 10),
                      "Expected Undo toast after copying a set (Undo button missing).")
        undoBtn.tap()

        XCTAssertTrue(waitForElementToDisappear(app: app, identifier: addedID, timeout: 12),
                      "Expected the copied set row to disappear after Undo.")
    }

    // MARK: - Navigation to Session

    private func startFirstRoutineSessionIfNeeded(_ app: XCUIApplication) {
        if waitForSessionScreen(app: app, timeout: 1.0) { return }

        // Tap the first routine row (tables or collection).
        if app.tables.cells.firstMatch.waitForExistence(timeout: 2) {
            app.tables.cells.firstMatch.tap()
        } else if app.collectionViews.cells.firstMatch.waitForExistence(timeout: 2) {
            app.collectionViews.cells.firstMatch.tap()
        }

        // In routine detail, tap a Start button (label varies).
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

    // MARK: - Set Row Identification

    private func setToggleElements(in app: XCUIApplication) -> [XCUIElement] {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "WorkoutSetEditorRow.", ".DoneToggle")
        ).allElementsBoundByIndex
    }

    private func setToggleIDs(in app: XCUIApplication) -> Set<String> {
        Set(setToggleElements(in: app).map { $0.identifier }.filter { !$0.isEmpty })
    }

    private func waitForNewSetToggleID(after before: Set<String>, timeout: TimeInterval) -> String? {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let after = setToggleIDs(in: app)
            let diff = after.subtracting(before)
            if let first = diff.first {
                return first
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return nil
    }

    private func waitForElementToDisappear(app: XCUIApplication, identifier: String, timeout: TimeInterval) -> Bool {
        let el = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if !el.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return !el.exists
    }

    // MARK: - Finders

    private func firstDoneToggle(in app: XCUIApplication) -> XCUIElement {
        setToggleElements(in: app).first ?? app.buttons.firstMatch
    }

    private func firstAddSetButton(in app: XCUIApplication) -> XCUIElement {
        let byId = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "WorkoutSetEditorRow.", ".Actions.AddButton")
        ).firstMatch
        if byId.exists { return byId }

        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add")).firstMatch
    }

    private func firstCopySetButton(in app: XCUIApplication) -> XCUIElement {
        let byId = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "WorkoutSetEditorRow.", ".Actions.CopyButton")
        ).firstMatch
        if byId.exists { return byId }

        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Copy")).firstMatch
    }

    private func firstUndoButton(in app: XCUIApplication) -> XCUIElement {
        let byId = app.descendants(matching: .any).matching(identifier: "UndoToastView.UndoButton").firstMatch
        if byId.exists { return byId }
        return app.buttons.matching(NSPredicate(format: "label == %@", "Undo")).firstMatch
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
            if setToggleElements(in: app).count > 0 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return setToggleElements(in: app).count > 0
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
}
