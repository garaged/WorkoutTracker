import Foundation

enum TrackedActivityHealthPreferences {
    /// Why this file lives in `Services/HealthKit`:
    /// it centralizes small persisted settings that affect HealthKit export behavior
    /// without forcing UI screens to duplicate raw UserDefaults keys.
    static let autoSaveCompletedActivitiesKey = "trackedActivity.health.autoSaveCompletedActivities"
}
