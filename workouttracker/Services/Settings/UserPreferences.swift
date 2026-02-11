import Foundation
import Combine

/// Centralized user preferences backed by UserDefaults.
///
/// Why this lives in `workouttracker/Services/Settings`:
/// - This is app state (not UI) and is shared across many screens.
/// - Keeping all keys + defaults here prevents drift.
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    private enum Keys {
        static let weightUnit = UnitPreferences.Keys.weightUnitRaw
        static let defaultRestSeconds = "prefs.defaultRestSeconds"
        static let hapticsEnabled = "prefs.hapticsEnabled"
        static let autoStartRest = "prefs.autoStartRest"
        static let confirmDestructiveActions = "prefs.confirmDestructiveActions"
        static let lastBackupAt = "prefs.lastBackupAt"
        static let diagnosticsVerboseLoggingEnabled = "prefs.diagnosticsVerboseLoggingEnabled" // ✅ add
    }

    private let defaults: UserDefaults

    // MARK: - Preferences

    @Published var weightUnit: WeightUnit {
        didSet { defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit) }
    }

    @Published var defaultRestSeconds: Int {
        didSet { defaults.set(defaultRestSeconds, forKey: Keys.defaultRestSeconds) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    @Published var autoStartRest: Bool {
        didSet { defaults.set(autoStartRest, forKey: Keys.autoStartRest) }
    }

    @Published var confirmDestructiveActions: Bool {
        didSet { defaults.set(confirmDestructiveActions, forKey: Keys.confirmDestructiveActions) }
    }

    /// Updated by backup export flows to reassure the user.
    @Published var lastBackupAt: Date? {
        didSet {
            if let lastBackupAt {
                defaults.set(lastBackupAt.timeIntervalSince1970, forKey: Keys.lastBackupAt)
            } else {
                defaults.removeObject(forKey: Keys.lastBackupAt)
            }
        }
    }

    /// When enabled, the app writes extra debug logs.
    /// Useful for real-world troubleshooting + exporting logs.
    @Published var diagnosticsVerboseLoggingEnabled: Bool {
        didSet { defaults.set(diagnosticsVerboseLoggingEnabled, forKey: Keys.diagnosticsVerboseLoggingEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Weight unit
        if let raw = defaults.string(forKey: Keys.weightUnit), let u = WeightUnit(rawValue: raw) {
            self.weightUnit = u
        } else {
            self.weightUnit = .kg
        }

        // Rest seconds
        let rest = defaults.object(forKey: Keys.defaultRestSeconds) as? Int
        self.defaultRestSeconds = rest ?? 120

        // Behavior toggles
        self.hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        self.autoStartRest = defaults.object(forKey: Keys.autoStartRest) as? Bool ?? true
        self.confirmDestructiveActions = defaults.object(forKey: Keys.confirmDestructiveActions) as? Bool ?? true

        // Last backup
        if defaults.object(forKey: Keys.lastBackupAt) != nil {
            let ts = defaults.double(forKey: Keys.lastBackupAt)
            self.lastBackupAt = Date(timeIntervalSince1970: ts)
        } else {
            self.lastBackupAt = nil
        }

        // Diagnostics
        if defaults.object(forKey: Keys.diagnosticsVerboseLoggingEnabled) == nil {
            self.diagnosticsVerboseLoggingEnabled = false
        } else {
            self.diagnosticsVerboseLoggingEnabled = defaults.bool(forKey: Keys.diagnosticsVerboseLoggingEnabled)
        }
    }

    // MARK: - Derived labels

    var defaultRestLabel: String {
        if defaultRestSeconds <= 0 { return "Off" }
        let m = defaultRestSeconds / 60
        let s = defaultRestSeconds % 60
        if m > 0 && s > 0 { return "\(m)m \(s)s" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    // MARK: - Reset

    func resetToDefaults() {
        weightUnit = .kg
        defaultRestSeconds = 120
        hapticsEnabled = true
        autoStartRest = true
        confirmDestructiveActions = true
        diagnosticsVerboseLoggingEnabled = false
        lastBackupAt = nil
    }
}
