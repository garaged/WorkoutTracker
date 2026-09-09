import Foundation

/// Value policy only: this carries no workout data or entitlement state.
struct ExperiencePreferenceState: Codable, Equatable, Sendable {
    enum Mode: String, Codable, Sendable { case easy, pro }
    private(set) var effective: Mode
    private(set) var requested: Mode?

    static func bootstrap(isExistingInstallation: Bool) -> Self {
        Self(effective: isExistingInstallation ? .pro : .easy, requested: nil)
    }
    mutating func request(_ mode: Mode, hasActiveSession: Bool) {
        if hasActiveSession {
            requested = mode == effective ? nil : mode
        } else {
            effective = mode
            requested = nil
        }
    }
    mutating func applyPendingIfIdle(hasActiveSession: Bool) {
        guard !hasActiveSession, let requested else { return }
        effective = requested
        self.requested = nil
    }
}
