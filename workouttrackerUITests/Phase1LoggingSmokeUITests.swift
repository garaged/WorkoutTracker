import XCTest

final class Phase1LoggingSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_done_thenUndo_smoke() {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_SEED"] = "1"
        app.launchArguments = ["-uiTesting"]   // keep if you still use this elsewhere
        app.launch()
        
        assertOnSessionScreen(app)
        
        // Find and tap first done toggle.
        let doneToggle = firstDoneToggle(in: app)
        XCTAssertTrue(doneToggle.waitForExistence(timeout: 8), "Expected at least one set row.")
        doneToggle.tap()

        // ✅ Prove the tap actually toggled completion (label should flip).
        XCTAssertTrue(waitForAnyDoneStateFlip(in: app, timeout: 5),
                      "Done toggle did not flip state (tap may not have executed).")

        // ✅ Wait for Undo toast by finding an Undo button (identifier OR label fallback).
        let undoBtn = firstUndoButton(in: app)
        XCTAssertTrue(undoBtn.waitForExistence(timeout: 8),
                      "Expected Undo toast after completing a set (Undo button missing).")

        undoBtn.tap()

        // Toast should disappear after undo (either button or container can vanish depending on SwiftUI).
        XCTAssertTrue(waitForUndoToastToDisappear(in: app, timeout: 8),
                      "Expected Undo toast to disappear after undo.")
    }

    func test_addSet_showsUndo_andUndoRestoresSetCount() {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_SEED"] = "1"
        app.launchArguments = ["-uiTesting"]   // keep if you still use this elsewhere
        app.launch()

        assertOnSessionScreen(app)
        
        let initialCount = countSetRows(in: app)
        XCTAssertGreaterThan(initialCount, 0, "Expected at least 1 set row visible.")

        // Tap "+ set" (identifier first, label fallback)
        let addButton = firstAddSetButton(in: app)
        XCTAssertTrue(addButton.waitForExistence(timeout: 8), "Expected an Add Set button.")
        addButton.tap()

        // ✅ Prove the add actually happened (count increments), THEN look for undo.
        XCTAssertTrue(waitForSetRowCount(app: app, expected: initialCount + 1, timeout: 8),
                      "Expected set count to increase after adding a set.")
        XCTAssertEqual(countSetRows(in: app), initialCount + 1)

        // ✅ Wait for Undo toast via Undo button (identifier OR label fallback).
        let undoBtn = firstUndoButton(in: app)
        XCTAssertTrue(undoBtn.waitForExistence(timeout: 8),
                      "Expected Undo toast after adding a set (Undo button missing).")

        undoBtn.tap()

        XCTAssertTrue(waitForSetRowCount(app: app, expected: initialCount, timeout: 8),
                      "Expected set count to restore after Undo.")
        XCTAssertEqual(countSetRows(in: app), initialCount)

        XCTAssertTrue(waitForUndoToastToDisappear(in: app, timeout: 8),
                      "Expected Undo toast to disappear after undo.")
    }
    
    func test_copySet_showsUndo_andUndoRestoresSetCount() {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_SEED"] = "1"
        app.launchArguments = ["-uiTesting"]   // keep if you still use this elsewhere
        app.launch()

        assertOnSessionScreen(app)
        
        let initialCount = countSetRows(in: app)
        XCTAssertGreaterThan(initialCount, 0, "Expected at least 1 set row visible.")

        // Tap "Copy set" in the row action bar.
        let copyButton = firstCopySetButton(in: app)
        XCTAssertTrue(copyButton.waitForExistence(timeout: 8), "Expected a Copy button.")
        copyButton.tap()

        // Prove copy happened (count increments), then undo.
        XCTAssertTrue(waitForSetRowCount(app: app, expected: initialCount + 1, timeout: 8),
                      "Expected set count to increase after copying a set.")
        XCTAssertEqual(countSetRows(in: app), initialCount + 1)

        let undoBtn = firstUndoButton(in: app)
        XCTAssertTrue(undoBtn.waitForExistence(timeout: 8),
                      "Expected Undo toast after copying a set (Undo button missing).")
        undoBtn.tap()

        XCTAssertTrue(waitForSetRowCount(app: app, expected: initialCount, timeout: 8),
                      "Expected set count to restore after Undo.")
        XCTAssertEqual(countSetRows(in: app), initialCount)
    }

    // MARK: - Finders

    private func firstDoneToggle(in app: XCUIApplication) -> XCUIElement {
        // Preferred: stable per-row identifier
        let byId = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "WorkoutSetEditorRow.", ".DoneToggle")
        ).firstMatch
        if byId.exists { return byId }

        // Fallback: label exposed by your row
        return app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Mark set")
        ).firstMatch
    }

    private func firstAddSetButton(in app: XCUIApplication) -> XCUIElement {
        // Preferred: per-row action bar add
        let byId = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "WorkoutSetEditorRow.", ".Actions.AddButton")
        ).firstMatch
        if byId.exists { return byId }

        // Fallback: any "Add set" button
        return app.buttons.matching(
            NSPredicate(format: "label == %@", "Add set")
        ).firstMatch
    }

    private func firstUndoButton(in app: XCUIApplication) -> XCUIElement {
        // Preferred: explicit identifier
        let byId = app.buttons["UndoToastView.UndoButton"]
        if byId.exists { return byId }

        // Fallback: SwiftUI sometimes drops identifiers but preserves the label.
        let byLabel = app.buttons.matching(NSPredicate(format: "label == %@", "Undo")).firstMatch
        if byLabel.exists { return byLabel }

        // Last resort: anything with label containing "Undo"
        return app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Undo")).firstMatch
    }
    
    private func firstCopySetButton(in app: XCUIApplication) -> XCUIElement {
        // Preferred: per-row action bar copy
        let byId = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "WorkoutSetEditorRow.", ".Actions.CopyButton")
        ).firstMatch
        if byId.exists { return byId }

        // Fallback: label
        return app.buttons.matching(
            NSPredicate(format: "label == %@", "Copy set")
        ).firstMatch
    }

    // MARK: - Assertions / waits

    private func countSetRows(in app: XCUIApplication) -> Int {
        let byId = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "WorkoutSetEditorRow.", ".DoneToggle")
        ).count
        if byId > 0 { return byId }

        return app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Mark set")
        ).count
    }

    private func waitForSetRowCount(app: XCUIApplication, expected: Int, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if countSetRows(in: app) == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }

    private func waitForAnyDoneStateFlip(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        // When completed, row toggle label becomes "Mark set not completed".
        let completedLabel = app.buttons.matching(NSPredicate(format: "label == %@", "Mark set not completed")).firstMatch
        if completedLabel.exists { return true }

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if completedLabel.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return completedLabel.exists
    }

    private func waitForUndoToastToDisappear(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let container = app.otherElements["UndoToastView.Container"]
        let undoById = app.buttons["UndoToastView.UndoButton"]
        let undoByLabel = app.buttons.matching(NSPredicate(format: "label == %@", "Undo")).firstMatch

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let containerGone = !container.exists
            let undoGone = !undoById.exists && !undoByLabel.exists
            if containerGone && undoGone { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return !container.exists && !undoById.exists && !undoByLabel.exists
    }
    
    private func firstExistingElement(candidates: [XCUIElement]) -> XCUIElement {
        for c in candidates where c.exists { return c }
        return candidates.first ?? XCUIApplication().otherElements.firstMatch
    }
    
    private func waitForSessionScreen(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let candidates: [XCUIElement] = [
            app.otherElements["WorkoutSession.Screen"],
            app.tables["WorkoutSession.Screen"],
            app.scrollViews["WorkoutSession.Screen"],
            app.buttons["WorkoutSession.ContinueButton"],

            // Last-resort proof: any set row toggle exists
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                            "WorkoutSetEditorRow.", ".DoneToggle")
            ).firstMatch
        ]

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if candidates.contains(where: { $0.exists }) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return candidates.contains(where: { $0.exists })
    }

    private func assertOnSessionScreen(_ app: XCUIApplication,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        if waitForSessionScreen(app: app, timeout: 12) { return }

        // ✅ Screenshot from the screen (or you can use app.screenshot())
        let shot = XCUIScreen.main.screenshot()
        let shotAttachment = XCTAttachment(screenshot: shot)
        shotAttachment.name = "UI Screenshot (not on session)"
        shotAttachment.lifetime = XCTAttachment.Lifetime.keepAlways
        add(shotAttachment)

        let treeAttachment = XCTAttachment(string: app.debugDescription)
        treeAttachment.name = "UI Hierarchy Dump"
        treeAttachment.lifetime = XCTAttachment.Lifetime.keepAlways
        add(treeAttachment)

        XCTFail("Expected to land on session screen.", file: file, line: line)
    }
}
