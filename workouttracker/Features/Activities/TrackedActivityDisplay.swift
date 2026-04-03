import Foundation

extension TrackedActivityKind {
    var displayName: String {
        switch self {
        case .walking:
            return String(localized: "activities.kind.walking", defaultValue: "Walking")
        case .running:
            return String(localized: "activities.kind.running", defaultValue: "Running")
        case .hiking:
            return String(localized: "activities.kind.hiking", defaultValue: "Hiking")
        case .yoga:
            return String(localized: "activities.kind.yoga", defaultValue: "Yoga")
        }
    }

    var systemImage: String {
        switch self {
        case .walking:
            return "figure.walk"
        case .running:
            return "figure.run"
        case .hiking:
            return "figure.hiking"
        case .yoga:
            return "figure.yoga"
        }
    }

    var startVerb: String {
        switch self {
        case .walking:
            return String(localized: "activities.action.start_walk", defaultValue: "Start walk")
        case .running:
            return String(localized: "activities.action.start_run", defaultValue: "Start run")
        case .hiking:
            return String(localized: "activities.action.start_hike", defaultValue: "Start hike")
        case .yoga:
            return String(localized: "activities.action.start_yoga", defaultValue: "Start yoga")
        }
    }

    var helperText: String {
        switch self {
        case .walking:
            return String(
                localized: "activities.helper.walking",
                defaultValue: "Duration is always tracked. Distance, steps, and energy can be added after you finish."
            )
        case .running:
            return String(
                localized: "activities.helper.running",
                defaultValue: "Duration is always tracked. Distance, energy, and steps can be added after you finish."
            )
        case .hiking:
            return String(
                localized: "activities.helper.hiking",
                defaultValue: "Duration is always tracked. Distance, energy, and steps can be added after you finish."
            )
        case .yoga:
            return String(
                localized: "activities.helper.yoga",
                defaultValue: "Duration is always tracked. Energy and notes can be added after you finish."
            )
        }
    }
}

extension ActivityEnvironment {
    var displayName: String {
        switch self {
        case .indoor:
            return String(localized: "activities.environment.indoor", defaultValue: "Indoor")
        case .outdoor:
            return String(localized: "activities.environment.outdoor", defaultValue: "Outdoor")
        case .unspecified:
            return String(localized: "activities.environment.automatic", defaultValue: "Automatic")
        }
    }
}

extension TrackedActivityLifecycleState {
    var badgeText: String {
        switch self {
        case .planned:
            return String(localized: "activities.lifecycle.planned", defaultValue: "Planned")
        case .inProgress:
            return String(localized: "activities.lifecycle.live", defaultValue: "Live")
        case .paused:
            return String(localized: "activities.lifecycle.paused", defaultValue: "Paused")
        case .completed:
            return String(localized: "activities.lifecycle.completed", defaultValue: "Completed")
        case .discarded:
            return String(localized: "activities.lifecycle.discarded", defaultValue: "Discarded")
        }
    }
}

extension HealthKitExportState {
    var displayName: String {
        switch self {
        case .notRequested:
            return String(localized: "health.export_state.not_saved", defaultValue: "Not saved")
        case .notAvailable:
            return String(localized: "health.export_state.unavailable", defaultValue: "Unavailable")
        case .pending:
            return String(localized: "health.export_state.saving", defaultValue: "Saving")
        case .exported:
            return String(localized: "health.export_state.saved", defaultValue: "Saved")
        case .failed:
            return String(localized: "health.export_state.failed", defaultValue: "Save failed")
        }
    }

    var helperText: String {
        switch self {
        case .notRequested:
            return String(
                localized: "health.export_state_helper.not_saved",
                defaultValue: "This tracked activity has not been saved to Apple Health yet."
            )
        case .notAvailable:
            return String(
                localized: "health.export_state_helper.unavailable",
                defaultValue: "Apple Health is not available on this device."
            )
        case .pending:
            return String(
                localized: "health.export_state_helper.saving",
                defaultValue: "WorkoutTracker is currently saving this tracked activity to Apple Health."
            )
        case .exported:
            return String(
                localized: "health.export_state_helper.saved",
                defaultValue: "This tracked activity was saved to Apple Health. Later edits in WorkoutTracker do not update the already-saved Health workout in this release."
            )
        case .failed:
            return String(
                localized: "health.export_state_helper.failed",
                defaultValue: "The last Apple Health save attempt did not complete. You can retry after checking permissions."
            )
        }
    }
}
