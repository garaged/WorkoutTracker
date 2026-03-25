import XCTest

final class FinishSummarySmokeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_finishSummary_showsHonestCounts_afterCompletingOneSet() {
        app = UITestLaunch.app(start: "session", reset: true, seed: true)
        app.launch()

        assertOnSessionScreen(app)
        tapFirstDoneToggle(app)
        tapFinish(app)
        confirmFinishAndSave(app)
        dismissReflectionSheetIfVisible(app)

        let summary = app.otherElements["WorkoutSession.FinishSummary"]
        if !summary.waitForExistence(timeout: 8) {
            attachUITestDebug(app, name: "FinishSummary_NormalSummaryMissing")
        }
        XCTAssertTrue(summary.exists, "Expected finish summary after saving a session.")

        let completedSetsTile = identifiedElement("WorkoutSession.FinishSummary.CompletedSets")
        XCTAssertTrue(
            completedSetsTile.waitForExistence(timeout: 2),
            "Expected completed-sets tile in finish summary."
        )
        XCTAssertTrue(
            completedSetsTile.label.contains("1"),
            "Expected completed-sets tile to reflect one completed set. Actual label: \(completedSetsTile.label)"
        )

        XCTAssertTrue(identifiedElement("WorkoutSession.FinishSummary.SkippedSets").exists)
        XCTAssertTrue(identifiedElement("WorkoutSession.FinishSummary.Elapsed").exists)
        XCTAssertTrue(identifiedElement("WorkoutSession.FinishSummary.Status").exists)
        XCTAssertTrue(identifiedElement("WorkoutSession.FinishSummary.AccessibleSummary").exists)
    }

    func test_finishSummary_lowDataSession_showsHonestyNote() {
        app = UITestLaunch.app(start: "session", reset: true, seed: true)
        app.launch()

        assertOnSessionScreen(app)
        tapFinish(app)
        confirmFinishAndSave(app)
        dismissReflectionSheetIfVisible(app)

        let summary = app.otherElements["WorkoutSession.FinishSummary"]
        if !summary.waitForExistence(timeout: 8) {
            attachUITestDebug(app, name: "FinishSummary_LowDataSummaryMissing")
        }
        XCTAssertTrue(summary.exists, "Expected finish summary after ending a low-data session.")
        let completedSetsTile = identifiedElement("WorkoutSession.FinishSummary.CompletedSets")
        XCTAssertTrue(
            completedSetsTile.waitForExistence(timeout: 2),
            "Expected completed-sets tile in low-data finish summary."
        )
        XCTAssertTrue(
            completedSetsTile.label.contains("0"),
            "Expected completed-sets tile to reflect zero completed sets. Actual label: \(completedSetsTile.label)"
        )
        XCTAssertTrue(
            identifiedElement("WorkoutSession.FinishSummary.PRs").waitForExistence(timeout: 2),
            "Expected PR section to still render for low-data sessions."
        )
    }
    
    private func identifiedElement(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: id)
            .firstMatch
    }
    
    private var doneTogglePredicate: NSPredicate {
        NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    "WorkoutSetEditorRow.", ".DoneToggle")
    }

    private func tapFirstDoneToggle(_ app: XCUIApplication) {
        let actionableRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if actionableRow.waitForExistence(timeout: 5) {
            let toggle = actionableRow.buttons.matching(doneTogglePredicate).firstMatch
            if toggle.exists {
                tapSafely(toggle)
                return
            }
        }

        let fallback = app.buttons.matching(doneTogglePredicate).firstMatch
        if !fallback.waitForExistence(timeout: 5) {
            attachUITestDebug(app, name: "FinishSummary_DoneToggleMissing")
        }
        XCTAssertTrue(fallback.exists, "Expected a done toggle before finishing the session.")
        tapSafely(fallback)
    }

    private func tapFinish(_ app: XCUIApplication) {
        let finish = app.buttons["WorkoutSession.FinishButton"]
        if !finish.waitForExistence(timeout: 4) {
            attachUITestDebug(app, name: "FinishSummary_FinishButtonMissing")
        }
        XCTAssertTrue(finish.exists, "Expected Finish button.")
        tapSafely(finish)
    }

    private func confirmFinishAndSave(_ app: XCUIApplication) {
        let candidates: [XCUIElement] = [
            app.buttons["WorkoutSession.FinishConfirmButton"],
            app.buttons["Finish & Save"],
            app.buttons["session.finish_workout.action"],
            app.descendants(matching: .button)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "finish_workout.action"))
                .firstMatch
        ]

        if let button = waitAny(candidates, timeout: 4) {
            tapSafely(button)
            return
        }

        attachUITestDebug(app, name: "FinishSummary_FinishConfirmMissing")
        XCTFail("Expected Finish confirmation action.")
    }

    private func dismissReflectionSheetIfVisible(_ app: XCUIApplication) {
        let notNow = app.buttons["SessionReflection.NotNow"]
        if notNow.waitForExistence(timeout: 6) {
            tapSafely(notNow)
        }
    }

    private func assertOnSessionScreen(_ app: XCUIApplication,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        let screen = app.otherElements["WorkoutSession.Screen"]
        if screen.waitForExistence(timeout: 10) { return }

        attachUITestDebug(app, name: "FinishSummary_NotOnSession", file: file, line: line)
        XCTFail("Expected to land on session screen.", file: file, line: line)
    }

    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func waitAny(_ candidates: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for candidate in candidates where candidate.exists { return candidate }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return candidates.first(where: { $0.exists })
    }
}
