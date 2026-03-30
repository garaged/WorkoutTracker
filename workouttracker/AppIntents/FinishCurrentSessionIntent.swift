import Foundation
import AppIntents

struct FinishCurrentSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish Current Session"
    static let description = IntentDescription("Finish your current workout session and return to Workout Tracker.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinator = IntentActionCoordinator()
        let outcome = try coordinator.finishCurrentSession()

        switch outcome {
        case .opened(let route):
            IntentLaunchBridge.stage(route: route)
            return .result(dialog: "Finishing your workout session in Workout Tracker.")
        case .blocked(let failure):
            return .result(dialog: IntentDialogFactory.dialog(for: failure))
        }
    }
}
