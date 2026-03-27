import XCTest
import UIKit

final class SessionAccessibilitySmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_session_largeText_actionableRowAndRestTimerRemainUsable() {
        let app = UITestLaunch.app(
            start: "session",
            reset: true,
            seed: true,
            preferredContentSizeCategory: .accessibilityExtraExtraLarge,
            extraEnv: ["UITESTS_REST_TIMER_SHORT": "1"]
        )
        app.launch()

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "SessionAccessibility_SessionMissing")
        }
        XCTAssertTrue(sessionScreen.exists, "Expected WorkoutSession screen under large text.")

        let actionableRow = app.otherElements["WorkoutSession.ActionableSetRow"]
        if !actionableRow.waitForExistence(timeout: t(6)) {
            attachUITestDebug(app, name: "SessionAccessibility_ActionableRowMissing")
        }
        XCTAssertTrue(actionableRow.exists, "Expected actionable set row under large text.")

        let restTimerButton = app.buttons["WorkoutSession.RestTimerButton"]
        if !restTimerButton.waitForExistence(timeout: t(4)) || !restTimerButton.isHittable {
            attachUITestDebug(app, name: "SessionAccessibility_RestTimerButtonNotHittable")
        }
        XCTAssertTrue(restTimerButton.exists, "Expected rest timer toolbar button.")
        XCTAssertTrue(restTimerButton.isHittable, "Expected rest timer toolbar button to remain hittable.")
        restTimerButton.tap()

        let timerContainer = app.otherElements["RestTimerView.Container"]
        if !timerContainer.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "SessionAccessibility_RestTimerMissing")
        }
        XCTAssertTrue(timerContainer.exists, "Expected rest timer overlay to appear.")

        let finishRest = app.buttons["RestTimerView.FinishButton"]
        if !finishRest.waitForExistence(timeout: t(4)) || !finishRest.isHittable {
            attachUITestDebug(app, name: "SessionAccessibility_FinishRestNotHittable")
        }
        XCTAssertTrue(finishRest.exists, "Expected Finish rest control.")
        XCTAssertTrue(finishRest.isHittable, "Expected Finish rest control to remain hittable under large text.")

        let continueButton = app.buttons["WorkoutSession.ContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: t(4)), "Expected Continue button under large text.")
        XCTAssertTrue(continueButton.isHittable, "Expected Continue button to remain hittable under large text.")
    }


    func test_session_underSpanishMexicoLocale_keepsExerciseLabelsReadable() {
        let app = UITestLaunch.app(
            start: "session",
            reset: true,
            seed: true,
            extraEnv: ["UITESTS_LOCALIZATION": "1"],
            extraArgs: ["-AppleLanguages", "(es-MX)", "-AppleLocale", "es_MX"]
        )
        app.launch()

        let sessionScreen = app.el("WorkoutSession.Screen")
        if !sessionScreen.waitForExistence(timeout: t(8)) {
            attachUITestDebug(app, name: "SessionAccessibility_esMX_SessionMissing")
        }
        XCTAssertTrue(sessionScreen.exists, "Expected WorkoutSession screen under es-MX.")

        let readableExerciseLabel = app.staticTexts.matching(
            NSPredicate(format: "label == %@ OR label == %@ OR label == %@", "Press de banca", "Sentadilla trasera", "Peso muerto")
        ).firstMatch
        if !readableExerciseLabel.waitForExistence(timeout: t(4)) {
            attachUITestDebug(app, name: "SessionAccessibility_esMX_ExerciseLabelMissing")
        }
        XCTAssertTrue(readableExerciseLabel.exists, "Expected a readable localized built-in exercise label in the session UI.")
    }

}
