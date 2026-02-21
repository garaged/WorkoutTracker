// workouttrackerUITests/ProgramsV2SmokeUITests.swift
import XCTest

final class ProgramsV2SmokeUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_programsV2_seededCatalog_add_schedule_start_showsExercises() {
        let app = UITestLaunch.app(start: "settings", reset: true, seed: true)
        app.launch()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10), "Expected Settings screen.")

        // Open Programs
        let programsLink = app.el("settings.programsLink")
        XCTAssertTrue(programsLink.waitForExistence(timeout: 8), "Expected Settings → Programs link.")
        tapSafely(programsLink)

        XCTAssertTrue(app.navigationBars["Programs"].waitForExistence(timeout: 10), "Expected Programs screen.")

        // Go to Catalog
        let catalogTab = app.segmentedControls.buttons["Catalog"]
        if catalogTab.exists { tapSafely(catalogTab) }

        // Tap add (+)
        let addBtn = app.buttons["Add program to installed"].firstMatch
        XCTAssertTrue(addBtn.waitForExistence(timeout: 10), "Expected add button on catalog row.")
        tapSafely(addBtn)

        // Switch to Installed
        let installedTab = app.segmentedControls.buttons["Installed"]
        if installedTab.exists { tapSafely(installedTab) }

        // ✅ Wait for installed “Seed Program V2…” button (collection view cell content)
        let seedProgramBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Seed Program V2")
        ).firstMatch

        if !seedProgramBtn.waitForExistence(timeout: 12) {
            attachUITestDebug(app, name: "ProgramsV2Smoke_InstalledNeverPopulated")
            XCTFail("Expected Seed Program V2 to appear in Installed.")
        }
        tapSafely(seedProgramBtn)

        XCTAssertTrue(app.navigationBars["Program"].waitForExistence(timeout: 8), "Expected Program detail.")

        // Schedule
        let scheduleBtn = app.el("programs.detail.scheduleButton")
        XCTAssertTrue(scheduleBtn.waitForExistence(timeout: 6), "Expected Schedule button.")
        XCTAssertTrue(scheduleBtn.isEnabled, "Schedule should be enabled for seeded V2 catalog.")
        tapSafely(scheduleBtn)

        let confirm = app.el("programs.schedule.confirmButton")
        XCTAssertTrue(confirm.waitForExistence(timeout: 8), "Expected schedule confirm.")
        XCTAssertTrue(confirm.isEnabled, "Confirm should be enabled.")
        tapSafely(confirm)

        // After scheduling, we should be on calendar (either same root or switched by host)
        let startOverlay = app.el("DayTimeline.WorkoutOverlay.Start")
        if !startOverlay.waitForExistence(timeout: 12) {
            attachUITestDebug(app, name: "ProgramsV2Smoke_NoStartOverlay")
            XCTFail("Expected DayTimeline workout overlay Start.")
        }
        tapSafely(startOverlay)

        let activitiesCount = app.el("DayTimeline.Debug.ActivitiesCount")
        XCTAssertTrue(activitiesCount.waitForExistence(timeout: 12), "Expected timeline debug counts.")
        XCTAssertFalse(activitiesCount.label.contains("Activities: 0"), "Expected scheduled activities to be created.")
        
        // sanity: we really have a workout scheduled
        let workoutsCount = app.el("DayTimeline.Debug.WorkoutsCount")
        XCTAssertTrue(workoutsCount.waitForExistence(timeout: 12), "Expected timeline debug counts.")
        XCTAssertFalse(workoutsCount.label.contains("Workouts: 0"), "Expected at least one workout.")

        // ✅ scroll + tap Start reliably
        tapWorkoutStartOverlayOrFail(app, name: "ProgramsV2Smoke_CouldNotTapStart")

        // Now we should be in a workout/session screen; verify exercises render.
        let goblet = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Goblet")).firstMatch
        if !goblet.waitForExistence(timeout: 12) {
            attachUITestDebug(app, name: "ProgramsV2Smoke_NoExerciseAfterStart")
            XCTFail("Expected exercise name (Goblet) after starting scheduled workout.")
        }
    }

    // MARK: - Helpers

    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
    
    private func tapWorkoutStartOverlayOrFail(_ app: XCUIApplication, name: String) {
        let startBtn = app.buttons.matching(identifier: "DayTimeline.WorkoutOverlay.Start").firstMatch
        let timelineScroll = app.scrollViews.firstMatch

        // If we accidentally open the activity editor while searching, back out.
        func dismissNewActivityIfNeeded() {
            let nav = app.navigationBars["New Activity"].firstMatch
            if nav.exists {
                let cancel = app.buttons["Cancel"].firstMatch
                if cancel.exists { cancel.tap() }
            }
        }

        // Try to bring it into view. Depending on where the timeline initially lands,
        // we might need to scroll down or up.
        for _ in 0..<12 {
            dismissNewActivityIfNeeded()
            if startBtn.exists && startBtn.isHittable {
                startBtn.tap()
                return
            }
            if timelineScroll.exists { timelineScroll.swipeUp() }
        }

        for _ in 0..<12 {
            dismissNewActivityIfNeeded()
            if startBtn.exists && startBtn.isHittable {
                startBtn.tap()
                return
            }
            if timelineScroll.exists { timelineScroll.swipeDown() }
        }

        attachUITestDebug(app, name: name)
        XCTFail("Start overlay exists but could not be made hittable (likely off-screen).")
    }
}
