// workouttracker/Services/Settings/UserPreferences.swift
import Foundation
import Combine

/// Centralized, typed access to user preferences.
/// Opinionated: Views should NOT talk to UserDefaults/AppStorage directly.
/// They should bind to this object instead.
@MainActor
final class UserPreferences: ObservableObject {

    static let shared = UserPreferences()

    // MARK: - Keys

    private enum Keys {
        static let weightUnit = UnitPreferences.Keys.weightUnitRaw                 // String
        static let defaultRestSeconds = "prefs.defaultRestSeconds" // Int
        static let hapticsEnabled = "prefs.hapticsEnabled"         // Bool
        static let autoStartRest = "prefs.autoStartRest"           // Bool
        static let confirmDestructiveActions = "prefs.confirmDestructiveActions" // Bool
        static let lastBackupAt = "prefs.lastBackupAt" // Double (time interval)
        static let diagnosticsVerboseLoggingEnabled = "prefs.diagnosticsVerboseLoggingEnabled" // Bool
    }

    // MARK: - Backing store

    private let defaults: UserDefaults

    // MARK: - Published settings (bind from SwiftUI)

    /// Uses your existing domain enum: `Domain/Models/Workouts/WeightUnit.swift`
    /// Assumption (typical): WeightUnit is `RawRepresentable<String>` and has a sensible default case.
    @Published var weightUnit: WeightUnit {
        didSet { defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit) }
    }

    /// Default rest timer duration in seconds.
    @Published var defaultRestSeconds: Int {
        didSet { defaults.set(defaultRestSeconds, forKey: Keys.defaultRestSeconds) }
    }

    /// Master toggle for haptics in logging screens.
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    /// If true, after completing a set the app can auto-start the rest timer.
    @Published var autoStartRest: Bool {
        didSet { defaults.set(autoStartRest, forKey: Keys.autoStartRest) }
    }

    /// If true, show confirmations for destructive actions (delete/wipe).
    @Published var confirmDestructiveActions: Bool {
        didSet { defaults.set(confirmDestructiveActions, forKey: Keys.confirmDestructiveActions) }
    }

    /// If true, `.debug` logs are written to the app's shareable log file.
    /// Keep this off by default so exported logs stay lean.
    @Published var diagnosticsVerboseLoggingEnabled: Bool {
        didSet { defaults.set(diagnosticsVerboseLoggingEnabled, forKey: Keys.diagnosticsVerboseLoggingEnabled) }
    }
    
    // Add as Published property:
    @Published var lastBackupAt: Date? {
        didSet {
            if let d = lastBackupAt {
                defaults.set(d.timeIntervalSince1970, forKey: Keys.lastBackupAt)
            } else {
                defaults.removeObject(forKey: Keys.lastBackupAt)
            }
        }
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let t = defaults.object(forKey: Keys.lastBackupAt) as? Double
        self.lastBackupAt = t.map { Date(timeIntervalSince1970: $0) }


        // WeightUnit
        if let raw = defaults.string(forKey: Keys.weightUnit),
           let u = WeightUnit(rawValue: raw) {
            self.weightUnit = u
        } else {
            // Opinionated default: metric as default
            self.weightUnit = .kg
        }

        // Rest seconds
        let rest = defaults.object(forKey: Keys.defaultRestSeconds) as? Int
        self.defaultRestSeconds = rest ?? 120

        // Haptics
        if defaults.object(forKey: Keys.hapticsEnabled) == nil {
            self.hapticsEnabled = true
        } else {
            self.hapticsEnabled = defaults.bool(forKey: Keys.hapticsEnabled)
        }

        // Auto-start rest
        if defaults.object(forKey: Keys.autoStartRest) == nil {
            self.autoStartRest = true
        } else {
            self.autoStartRest = defaults.bool(forKey: Keys.autoStartRest)
        }

        // Confirm destructive actions
        if defaults.object(forKey: Keys.confirmDestructiveActions) == nil {
            self.confirmDestructiveActions = true
        } else {
            self.confirmDestructiveActions = defaults.bool(forKey: Keys.confirmDestructiveActions)
        }


        // Verbose diagnostics logging (debug-level logs)
        if defaults.object(forKey: Keys.diagnosticsVerboseLoggingEnabled) == nil {
            self.diagnosticsVerboseLoggingEnabled = false
        } else {
            self.diagnosticsVerboseLoggingEnabled = defaults.bool(forKey: Keys.diagnosticsVerboseLoggingEnabled)
        }
    }

    // MARK: - Convenience

    func resetToDefaults() {
        weightUnit = .kg
        defaultRestSeconds = 120
        hapticsEnabled = true
        autoStartRest = true
        confirmDestructiveActions = true
    }

    /// Small helper for UI display
    var defaultRestLabel: String {
        let m = defaultRestSeconds / 60
        let s = defaultRestSeconds % 60
        if m == 0 { return "\(s)s" }
        if s == 0 { return "\(m)m" }
        return "\(m)m \(s)s"
    }
}
