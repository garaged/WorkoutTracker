import AppIntents
import Foundation

struct StartRoutineIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Routine"
    static let description = IntentDescription("Start a workout routine in Workout Tracker.")
    static let openAppWhenRun = true

    @Parameter(title: "Routine")
    var routine: RoutineAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$routine)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinator = IntentActionCoordinator()
        let outcome = try coordinator.startRoutine(routineID: routine.id)

        switch outcome {
        case .opened(let route):
            IntentLaunchBridge.stage(route: route)
            return .result(dialog: IntentDialog(stringLiteral: "Opening \(routine.name) in Workout Tracker."))

        case .blocked(let failure):
            return .result(dialog: IntentDialogFactory.dialog(for: failure))
        }
    }
}
