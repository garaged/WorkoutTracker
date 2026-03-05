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

        // Open Programs using the same resilient pattern as ProgramsSettingsSmokeUITests.
        let programsLink = app.el("settings.programsLink")
        if programsLink.waitForExistence(timeout: 3) {
            tapSafely(programsLink)
        } else {
            let fallback = app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", "Programs")).firstMatch
            XCTAssertTrue(fallback.waitForExistence(timeout: 6), "Expected Programs row.")
            tapSafely(fallback)
        }

        XCTAssertTrue(app.navigationBars["Programs"].waitForExistence(timeout: 10), "Expected Programs screen.")

        // First see whether the seeded program is already installed.
        if let installedTab = waitAny([app.segmentedControls.buttons["Installed"]], timeout: 1),
           installedTab.exists {
            tapSafely(installedTab)
        }

        if let installedProgram = findProgramNamedSeedV2(in: app, timeout: 3) {
            tapSafely(installedProgram)
        } else {
            // Otherwise, go to Catalog and install using a broad add/install button search.
            let catalogTab = app.segmentedControls.buttons["Catalog"]
            if catalogTab.exists { tapSafely(catalogTab) }

            // Try the explicit label first, then broader add/install fallbacks.
            let addCandidates: [XCUIElement] = [
                app.buttons["Add program to installed"].firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Install")).firstMatch,
                app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS[c] %@", "add")).firstMatch,
                app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS[c] %@", "install")).firstMatch
            ]

            if let addBtn = waitAny(addCandidates, timeout: 8) {
                tapSafely(addBtn)
            }

            let installedTab = app.segmentedControls.buttons["Installed"]
            if installedTab.exists { tapSafely(installedTab) }

            guard let installedProgram = findProgramNamedSeedV2(in: app, timeout: 12) else {
                attachUITestDebug(app, name: "ProgramsV2Smoke_InstalledNeverPopulated")
                XCTFail("Expected Seed Program V2 to appear in Installed.")
                return
            }
            tapSafely(installedProgram)
        }

        XCTAssertTrue(app.navigationBars["Program"].waitForExistence(timeout: 8), "Expected Program detail.")

        guard let scheduleBtn = findScheduleAction(in: app, timeout: 8) else {
            attachUITestDebug(app, name: "ProgramsV2Smoke_ScheduleMissing")
            XCTFail("Expected Schedule button.")
            return
        }
        XCTAssertTrue(scheduleBtn.isEnabled, "Schedule should be enabled for seeded V2 catalog.")
        tapSafely(scheduleBtn)

        guard let confirm = findScheduleConfirm(in: app, timeout: 8) else {
            attachUITestDebug(app, name: "ProgramsV2Smoke_ScheduleConfirmMissing")
            XCTFail("Expected schedule confirm.")
            return
        }
        XCTAssertTrue(confirm.isEnabled, "Confirm should be enabled.")
        tapSafely(confirm)

        let startOverlay = app.el("DayTimeline.WorkoutOverlay.Start")
        if !startOverlay.waitForExistence(timeout: 12) {
            attachUITestDebug(app, name: "ProgramsV2Smoke_NoStartOverlay")
            XCTFail("Expected DayTimeline workout overlay Start.")
            return
        }

        let activitiesCount = app.el("DayTimeline.Debug.ActivitiesCount")
        XCTAssertTrue(activitiesCount.waitForExistence(timeout: 12), "Expected timeline debug counts.")
        XCTAssertFalse(activitiesCount.label.contains("Activities: 0"), "Expected scheduled activities to be created.")

        let workoutsCount = app.el("DayTimeline.Debug.WorkoutsCount")
        XCTAssertTrue(workoutsCount.waitForExistence(timeout: 12), "Expected timeline debug counts.")
        XCTAssertFalse(workoutsCount.label.contains("Workouts: 0"), "Expected at least one workout.")

        tapWorkoutStartOverlayOrFail(app, name: "ProgramsV2Smoke_CouldNotTapStart")

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

    private func findProgramNamedSeedV2(in app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        let query = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Seed Program V2")
        )
        let el = query.firstMatch
        if el.waitForExistence(timeout: timeout) { return el }

        for _ in 0..<12 {
            swipeScrollableUp(app)
            if el.exists { return el }
        }
        for _ in 0..<12 {
            swipeScrollableDown(app)
            if el.exists { return el }
        }
        return nil
    }

    private func findScheduleAction(in app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        func candidates() -> [XCUIElement] {
            [
                app.el("programs.detail.scheduleButton"),
                app.buttons["Schedule"],
                app.buttons["Schedule Program"],
                app.buttons["Schedule program"],
                app.buttons["Add to Calendar"],
                app.buttons["Add to calendar"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Schedule")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Calendar")).firstMatch,
                app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS[c] %@", "schedule")).firstMatch
            ]
        }

        if let action = waitAny(candidates(), timeout: timeout) { return action }
        for _ in 0..<8 {
            swipeScrollableUp(app)
            if let action = waitAny(candidates(), timeout: 0.4) { return action }
        }
        for _ in 0..<8 {
            swipeScrollableDown(app)
            if let action = waitAny(candidates(), timeout: 0.4) { return action }
        }
        return nil
    }

    private func findScheduleConfirm(in app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        let candidates: [XCUIElement] = [
            app.el("programs.schedule.confirmButton"),
            app.buttons["Confirm"],
            app.buttons["Schedule"],
            app.buttons["Done"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Confirm")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Schedule")).firstMatch
        ]
        return waitAny(candidates, timeout: timeout)
    }

    private func tapWorkoutStartOverlayOrFail(_ app: XCUIApplication, name: String) {
        let startBtn = app.buttons.matching(identifier: "DayTimeline.WorkoutOverlay.Start").firstMatch
        let timelineScroll = app.scrollViews.firstMatch

        func dismissNewActivityIfNeeded() {
            let nav = app.navigationBars["New Activity"].firstMatch
            if nav.exists {
                let cancel = app.buttons["Cancel"].firstMatch
                if cancel.exists { cancel.tap() }
            }
        }

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
