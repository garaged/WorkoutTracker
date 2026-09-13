import Foundation
import Combine

@MainActor
final class ExperiencePreferenceStore: ObservableObject {
    static let storageKey = "workouttracker.experiencePreference.v1"
    static let starterPackEvidenceKey = "workouttracker.starterPackVersion"
    static let shared = ExperiencePreferenceStore(
        defaults: .standard,
        isExistingInstallation: UserDefaults.standard.object(forKey: starterPackEvidenceKey) != nil
    )

    @Published private(set) var state: ExperiencePreferenceState
    private let defaults: UserDefaults

    private struct Snapshot: Codable {
        let version: Int
        let state: ExperiencePreferenceState
    }

    init(defaults: UserDefaults = .standard, isExistingInstallation: Bool) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
           snapshot.version == 1,
           snapshot.state.requested != snapshot.state.effective {
            state = snapshot.state
        } else {
            state = .bootstrap(isExistingInstallation: isExistingInstallation)
            persist()
        }
    }

    func request(_ mode: ExperiencePreferenceState.Mode, hasActiveSession: Bool) {
        let previous = state
        state.request(mode, hasActiveSession: hasActiveSession)
        persist()
        notifyIfEffectiveModeChanged(from: previous)
    }

    func applyPendingIfIdle(hasActiveSession: Bool) {
        let previous = state
        state.applyPendingIfIdle(hasActiveSession: hasActiveSession)
        if state != previous {
            persist()
            notifyIfEffectiveModeChanged(from: previous)
        }
    }

    private func notifyIfEffectiveModeChanged(from previous: ExperiencePreferenceState) {
        guard previous.effective != state.effective else { return }
        NotificationCenter.default.post(name: .workouttrackerExperiencePreferenceDidChange, object: nil)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Snapshot(version: 1, state: state)) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}


extension Notification.Name {
    static let workouttrackerExperiencePreferenceDidChange = Notification.Name("workouttracker.experiencePreferenceDidChange")
}
