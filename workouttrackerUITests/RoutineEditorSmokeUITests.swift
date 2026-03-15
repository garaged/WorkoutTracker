// File: workouttrackerUITests/RoutineEditorSmokeUITests.swift
import XCTest

final class RoutineEditorSmokeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_createRoutine_cancelImmediately_doesNotLeaveExtraRoutineRow() {
        app = UITestLaunch.app(start: "routines", reset: true, seed: true)
        app.launch()

        let createButton = app.buttons["Create routine"]
        XCTAssertTrue(createButton.waitForExistence(timeout: t(8)), "Expected Routines screen")

        let beforeCount = waitForStableRoutineRowCount(in: app, minimum: 1, timeout: t(8))
        XCTAssertGreaterThan(beforeCount, 0, "Expected at least one seeded routine row before opening create")

        tapSafely(createButton)

        XCTAssertTrue(app.navigationBars["New Routine"].waitForExistence(timeout: t(6)), "Expected New Routine editor")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: t(4)), "Expected Cancel button in New Routine editor")
        tapSafely(cancelButton)

        XCTAssertTrue(createButton.waitForExistence(timeout: t(6)), "Expected to return to Routines screen after cancel")

        let afterCount = waitForStableRoutineRowCount(in: app, minimum: 1, timeout: t(8))

        if afterCount != beforeCount {
            attachUITestDebug(app, name: "RoutineCreateCancel_RowCountChanged")
        }

        XCTAssertEqual(
            afterCount,
            beforeCount,
            "Canceling routine creation should not leave an extra blank/orphan routine row"
        )
    }

    // MARK: - Helpers

    private func tapSafely(_ el: XCUIElement) {
        if el.isHittable {
            el.tap()
        } else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func waitForStableRoutineRowCount(in app: XCUIApplication,
                                              minimum: Int,
                                              timeout: TimeInterval) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var lastCount = -1
        var stableSamples = 0

        while Date() < deadline {
            let count = routineRowCount(in: app)

            if count >= minimum {
                if count == lastCount {
                    stableSamples += 1
                } else {
                    stableSamples = 0
                    lastCount = count
                }

                if stableSamples >= 3 {
                    return count
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        return routineRowCount(in: app)
    }

    private func routineRowCount(in app: XCUIApplication) -> Int {
        // RoutinesScreen is a plain SwiftUI List of routine rows, so table/cell count is the
        // best low-coupling proxy for "how many routines are visible in the list".
        // Using a count rather than a specific title lets the test catch an accidental blank row.
        let tableCells = app.tables.cells.count
        if tableCells > 0 { return tableCells }

        let directCells = app.cells.count
        if directCells > 0 { return directCells }

        return 0
    }
}
