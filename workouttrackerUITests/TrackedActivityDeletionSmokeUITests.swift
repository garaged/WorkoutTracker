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

        let deleteAction = deleteButtonInDialog(app)
        if !deleteAction.waitForExistence(timeout: t(2)) {
            attachUITestDebug(app, name: "TrackedActivityDelete_DeleteActionMissing")
        }
        XCTAssertTrue(deleteAction.exists, "Expected a destructive delete action inside the confirmation sheet.")
        tapSafely(deleteAction)

        let unavailable = app.staticTexts["Summary unavailable"].firstMatch
        if !unavailable.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "TrackedActivityDelete_UnavailableStateMissing")
        }
        XCTAssertTrue(unavailable.exists, "Expected deleting the seeded tracked activity to remove the local summary session.")
        XCTAssertTrue(waitForNonExistence(screen, timeout: t(2)), "Expected the summary screen collection view to disappear after deleting the tracked activity.")
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

    private func deleteButtonInDialog(_ app: XCUIApplication) -> XCUIElement {
        let candidates: [XCUIElement] = [
            app.sheets.buttons["Delete activity"],
            app.alerts.buttons["Delete activity"],
            app.buttons["Delete activity"],
            app.sheets.buttons["Delete"],
            app.alerts.buttons["Delete"],
            app.buttons["Delete"]
        ]

        for candidate in candidates {
            if candidate.exists || candidate.waitForExistence(timeout: t(0.5)) {
                return candidate
            }
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
