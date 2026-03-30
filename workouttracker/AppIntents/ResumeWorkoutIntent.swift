import Foundation
import AppIntents

struct ResumeWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Workout"
    static let description = IntentDescription("Resume your current workout session and jump to the best next target.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinator = IntentActionCoordinator()
        let outcome = try coordinator.resumeCurrentSession()

        switch outcome {
        case .opened(let route):
            IntentLaunchBridge.stage(route: route)
            return .result(dialog: "Resuming your workout in Workout Tracker.")
        case .blocked(let failure):
            return .result(dialog: IntentDialogFactory.dialog(for: failure))
        }
    }
}
