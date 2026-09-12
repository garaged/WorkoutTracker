import Foundation
import Combine

@MainActor
final class ExperiencePreferenceStore: ObservableObject {
    static let storageKey = "workouttracker.experiencePreference.v1"
    @Published private(set) var state: ExperiencePreferenceState

    init(defaults: UserDefaults = .standard, isExistingInstallation: Bool) {
        state = .bootstrap(isExistingInstallation: isExistingInstallation)
    }

    func request(_ mode: ExperiencePreferenceState.Mode, hasActiveSession: Bool) {}
    func applyPendingIfIdle(hasActiveSession: Bool) {}
}
