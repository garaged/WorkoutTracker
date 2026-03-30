import Foundation
import AppIntents

struct GoToCurrentSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Go to Current Session"
    static let description = IntentDescription("Open your current workout session.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinator = IntentActionCoordinator()
        let outcome = try coordinator.openCurrentSession()

        switch outcome {
        case .opened(let route):
            IntentLaunchBridge.stage(route: route)
            return .result(dialog: "Opening your current workout session in Workout Tracker.")
        case .blocked(let failure):
            return .result(dialog: IntentDialogFactory.dialog(for: failure))
        }
    }
}
