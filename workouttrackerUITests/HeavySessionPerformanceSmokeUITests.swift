import XCTest

final class HeavySessionPerformanceSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_heavySeededSession_opensAndCanScrollToLaterContent() {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment["UITESTS_SEED"] = "1"
        app.launchEnvironment["UITESTS_START"] = "session-heavy"
        app.launchEnvironment["UITESTS_PERF_HEAVY_SESSION"] = "1"
        app.launchEnvironment["UITESTS_DISABLE_ANIMATIONS"] = "1"
        app.launch()

        let sessionScrollView = app.scrollViews["WorkoutSession.Screen"].firstMatch
        XCTAssertTrue(
            sessionScrollView.waitForExistence(timeout: 5),
            "Expected heavy seeded WorkoutSession scroll view."
        )

        let exerciseCardsQuery = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "WorkoutSession.ExerciseCard.")
        )
        let setRowsQuery = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "WorkoutSession.SetRow.")
        )
        let editorRowsQuery = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "WorkoutSetEditorRow.")
        )

        XCTAssertTrue(
            exerciseCardsQuery.firstMatch.waitForExistence(timeout: 5),
            "Expected at least one exercise card in the heavy seeded session."
        )

        XCTAssertTrue(
            setRowsQuery.firstMatch.waitForExistence(timeout: 5) ||
            editorRowsQuery.firstMatch.waitForExistence(timeout: 5),
            "Expected visible set content in the heavy seeded session."
        )

        let initiallyVisibleExerciseIDs = visibleExerciseCardIdentifiers(in: app)
        XCTAssertFalse(
            initiallyVisibleExerciseIDs.isEmpty,
            "Expected at least one visible exercise card identifier at launch."
        )

        var seenExerciseIDs = initiallyVisibleExerciseIDs
        var reachedLaterContent = false

        for _ in 0..<8 {
            sessionScrollView.swipeUp()

            let currentlyVisible = visibleExerciseCardIdentifiers(in: app)
            seenExerciseIDs.formUnion(currentlyVisible)

            if seenExerciseIDs.count > initiallyVisibleExerciseIDs.count {
                reachedLaterContent = true
                break
            }
        }

        XCTAssertTrue(
            reachedLaterContent,
            "Expected scrolling to reveal additional exercise cards in the heavy seeded session."
        )

        let firstVisibleExerciseID = initiallyVisibleExerciseIDs.first!
        var returnedToEarlierContent = false

        for _ in 0..<8 {
            sessionScrollView.swipeDown()

            let currentlyVisible = visibleExerciseCardIdentifiers(in: app)
            if currentlyVisible.contains(firstVisibleExerciseID) {
                returnedToEarlierContent = true
                break
            }
        }

        XCTAssertTrue(
            returnedToEarlierContent,
            "Expected earlier session content to remain reachable after scrolling back."
        )
    }

    private func visibleExerciseCardIdentifiers(in app: XCUIApplication) -> Set<String> {
        let query = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "WorkoutSession.ExerciseCard.")
        )

        let identifiers = query.allElementsBoundByIndex.compactMap { element -> String? in
            guard element.exists, !element.identifier.isEmpty else { return nil }
            guard element.isHittable else { return nil }
            return element.identifier
        }

        return Set(identifiers)
    }
}
