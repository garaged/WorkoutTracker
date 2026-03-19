import Foundation
import Combine
import SwiftUI

/// Centralized user preferences backed by UserDefaults.
///
/// Why this lives in `workouttracker/Services/Settings`:
/// - This is app state (not UI) and is shared across many screens.
/// - Keeping all keys + defaults here prevents drift.
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    private enum Keys {
        static let weightUnit = UnitPreferences.Keys.weightUnitRaw
        static let distanceUnit = UnitPreferences.Keys.distanceUnitRaw
        static let defaultRestSeconds = "prefs.defaultRestSeconds"
        static let hapticsEnabled = "prefs.hapticsEnabled"
        static let autoStartRest = "prefs.autoStartRest"
        static let restTimerCueEnabled = "prefs.restTimerCueEnabled"
        static let restTimerShowOverdue = "prefs.restTimerShowOverdue"
        static let restSoundCuesEnabled = "prefs.restSoundCuesEnabled"
        static let confirmDestructiveActions = "prefs.confirmDestructiveActions"
        static let lastBackupAt = "prefs.lastBackupAt"
        static let diagnosticsVerboseLoggingEnabled = "prefs.diagnosticsVerboseLoggingEnabled"
        static let exerciseIllustrationSet = "exerciseIllustrationSet"
    }

    private let defaults: UserDefaults

    // MARK: - Preferences

    @Published var weightUnit: WeightUnit {
        didSet { defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit) }
    }

    @Published var distanceUnit: DistanceUnit {
        didSet { defaults.set(distanceUnit.rawValue, forKey: Keys.distanceUnit) }
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

    @Published var restTimerCueEnabled: Bool {
        didSet { defaults.set(restTimerCueEnabled, forKey: Keys.restTimerCueEnabled) }
    }

    @Published var restTimerShowOverdue: Bool {
        didSet { defaults.set(restTimerShowOverdue, forKey: Keys.restTimerShowOverdue) }
    }

    var restSoundCuesEnabled: Bool {
        get { restTimerCueEnabled }
        set { restTimerCueEnabled = newValue }
    }

    @Published var confirmDestructiveActions: Bool {
        didSet { defaults.set(confirmDestructiveActions, forKey: Keys.confirmDestructiveActions) }
    }

    /// Selected bundled illustration family for exercise artwork.
    ///
    /// Stored as a raw value so the app can swap between neutral / female / male
    /// asset catalogs without rewriting Exercise records.
    @Published var exerciseIllustrationSet: ExerciseIllustrationSet {
        didSet { defaults.set(exerciseIllustrationSet.rawValue, forKey: Keys.exerciseIllustrationSet) }
    }

    /// When enabled, the app writes extra debug logs.
    /// Persisted via UserDefaults so it survives relaunch (used by UITests).
    @Published var diagnosticsVerboseLoggingEnabled: Bool {
        didSet { defaults.set(diagnosticsVerboseLoggingEnabled, forKey: Keys.diagnosticsVerboseLoggingEnabled) }
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: Keys.weightUnit), let u = WeightUnit(rawValue: raw) {
            self.weightUnit = u
        } else {
            self.weightUnit = .kg
        }

        if let raw = defaults.string(forKey: Keys.distanceUnit), let u = DistanceUnit(rawValue: raw) {
            self.distanceUnit = u
        } else {
            self.distanceUnit = .km
        }

        self.defaultRestSeconds = defaults.object(forKey: Keys.defaultRestSeconds) as? Int ?? 120

        self.restTimerCueEnabled =
            defaults.object(forKey: Keys.restTimerCueEnabled) as? Bool
            ?? defaults.object(forKey: Keys.restSoundCuesEnabled) as? Bool
            ?? true

        self.restTimerShowOverdue = defaults.object(forKey: Keys.restTimerShowOverdue) as? Bool ?? true

        self.hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        self.autoStartRest = defaults.object(forKey: Keys.autoStartRest) as? Bool ?? true
        self.confirmDestructiveActions = defaults.object(forKey: Keys.confirmDestructiveActions) as? Bool ?? true

        if let raw = defaults.string(forKey: Keys.exerciseIllustrationSet),
           let set = ExerciseIllustrationSet(rawValue: raw) {
            self.exerciseIllustrationSet = set
        } else {
            self.exerciseIllustrationSet = .dummyV1
        }

        if defaults.object(forKey: Keys.lastBackupAt) != nil {
            let ts = defaults.double(forKey: Keys.lastBackupAt)
            self.lastBackupAt = Date(timeIntervalSince1970: ts)
        } else {
            self.lastBackupAt = nil
        }

        self.diagnosticsVerboseLoggingEnabled = defaults.bool(forKey: Keys.diagnosticsVerboseLoggingEnabled)
    }

    // MARK: - Derived labels

    var defaultRestLabel: String {
        if defaultRestSeconds <= 0 { return String(localized: "common.off") }
        return AppFormatting.shortDuration(seconds: defaultRestSeconds)
    }

    // MARK: - Reset

    func resetToDefaults() {
        weightUnit = .kg
        distanceUnit = .km
        defaultRestSeconds = 120
        hapticsEnabled = true
        autoStartRest = true
        restTimerCueEnabled = true
        restTimerShowOverdue = true
        confirmDestructiveActions = true
        exerciseIllustrationSet = .dummyV1
        diagnosticsVerboseLoggingEnabled = false
        lastBackupAt = nil
    }
}
