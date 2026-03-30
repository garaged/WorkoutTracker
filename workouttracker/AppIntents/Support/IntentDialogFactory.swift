import Foundation
import AppIntents

enum IntentDialogFactory {
    static func dialog(for failure: IntentPreconditionFailure) -> IntentDialog {
        switch failure {
        case .routineNotFound:
            return "That routine is no longer available."
        case .noResumableSession:
            return "There isn't an active workout session to resume right now."
        case .noFinishableSession:
            return "There isn't an active workout session you can finish right now."
        case .noRestCapableContext:
            return "There isn't an active workout session ready for a rest timer right now."
        }
    }
}
