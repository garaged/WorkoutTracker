import XCTest

final class TrackedActivityDeletionSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_completedTrackedActivitySummary_deleteRemovesLocalCopyOnly() {
        let app = UITestLaunch.app(
            start: "tracked-summary",
            reset: true,
            seed: false,
            extraEnv: [
                "UITESTS_TRACKED_ACTIVITY_SEED": "1",
                "UITESTS_TRACKED_ACTIVITY_SUMMARY": "1"
            ]
        )
        app.launch()

        let screen = app.el("TrackedActivity.FinishSummary.Screen")
        if !screen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "TrackedActivityDelete_SummaryMissing")
        }
        XCTAssertTrue(screen.exists, "Expected the seeded tracked-activity summary screen.")

        let deleteButton = app.buttons["trackedActivity.deleteButton"].firstMatch
        if !deleteButton.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "TrackedActivityDelete_DeleteButtonMissing")
        }
        XCTAssertTrue(deleteButton.exists, "Expected a delete action in the tracked-activity summary.")
        tapSafely(deleteButton)

        let deleteSheet = deleteConfirmationSheet(in: app)
        if !deleteSheet.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "TrackedActivityDelete_ConfirmMissing")
        }
        XCTAssertTrue(deleteSheet.exists, "Expected a destructive delete confirmation for the tracked activity.")

        let workoutTrackerOnly = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "WorkoutTracker only")).firstMatch
        let appleHealth = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Apple Health")).firstMatch
        XCTAssertTrue(workoutTrackerOnly.waitForExistence(timeout: t(2)), "Expected delete messaging to mention WorkoutTracker-only deletion.")
        XCTAssertTrue(appleHealth.waitForExistence(timeout: t(2)), "Expected delete messaging to mention Apple Health scope explicitly.")

        let deleteAction = deleteButtonInDialog(app, within: deleteSheet)
        if !deleteAction.waitForExistence(timeout: t(2)) {
            attachUITestDebug(app, name: "TrackedActivityDelete_DeleteActionMissing")
        }
        XCTAssertTrue(deleteAction.exists, "Expected a destructive delete action inside the confirmation sheet.")
        tapSafely(deleteAction)

        if !waitForNonExistence(screen, timeout: t(6)) {
            attachUITestDebug(app, name: "TrackedActivityDelete_SummaryScreenStillVisible")
        }
        XCTAssertTrue(
            waitForNonExistence(screen, timeout: t(1)),
            "Expected deleting the seeded tracked activity to dismiss the summary screen after removing the local session."
        )
    }

    private func deleteConfirmationSheet(in app: XCUIApplication) -> XCUIElement {
        let titledSheet = app.sheets["Delete local activity?"].firstMatch
        if titledSheet.exists || titledSheet.waitForExistence(timeout: t(1)) {
            return titledSheet
        }

        let titledPopoverSheet = app.descendants(matching: .sheet)
            .matching(NSPredicate(format: "label == %@", "Delete local activity?"))
            .firstMatch
        if titledPopoverSheet.exists || titledPopoverSheet.waitForExistence(timeout: t(1)) {
            return titledPopoverSheet
        }

        return app.sheets.firstMatch
    }

    private func deleteButtonInDialog(_ app: XCUIApplication, within deleteSheet: XCUIElement) -> XCUIElement {
        let candidates: [XCUIElement] = [
            deleteSheet.buttons["Delete activity"],
            deleteSheet.descendants(matching: .button)
                .matching(NSPredicate(format: "label == %@", "Delete activity"))
                .firstMatch,
            deleteSheet.buttons["Delete"],
            deleteSheet.descendants(matching: .button)
                .matching(NSPredicate(format: "label == %@", "Delete"))
                .firstMatch,
            app.sheets.buttons["Delete activity"],
            app.alerts.buttons["Delete activity"],
            app.sheets.buttons["Delete"],
            app.alerts.buttons["Delete"]
        ]

        for candidate in candidates {
            if candidate.exists || candidate.waitForExistence(timeout: t(0.5)) {
                return candidate
            }
        }

        let fallbackCandidates = app.buttons
            .matching(NSPredicate(format: "label IN %@", ["Delete activity", "Delete"]))
            .allElementsBoundByIndex
            .filter { $0.identifier != "trackedActivity.deleteButton" }

        if let hittable = fallbackCandidates.first(where: \.isHittable) {
            return hittable
        }

        if let existing = fallbackCandidates.first(where: \.exists) {
            return existing
        }

        return app.buttons["Delete activity"].firstMatch
    }

    private func tapSafely(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
