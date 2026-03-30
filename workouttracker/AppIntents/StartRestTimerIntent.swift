import Foundation
import AppIntents

struct StartRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Rest Timer"
    static let description = IntentDescription("Open the rest timer when your current workout session is ready for one.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinator = IntentActionCoordinator()
        let outcome = try coordinator.startRest()

        switch outcome {
        case .opened(let route):
            IntentLaunchBridge.stage(route: route)
            return .result(dialog: "Opening the rest timer in Workout Tracker.")
        case .blocked(let failure):
            return .result(dialog: IntentDialogFactory.dialog(for: failure))
        }
    }
}
