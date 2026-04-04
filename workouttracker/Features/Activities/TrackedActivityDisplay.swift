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

extension TrackedActivitySession {
    var healthKitExportDisplayName: String {
        if healthKitExportState == .exported && hasLocalChangesSinceHealthKitExport {
            return String(
                localized: "health.export_state.saved_local_changes",
                defaultValue: "Saved (local changes)"
            )
        }
        return healthKitExportState.displayName
    }

    var healthKitExportHelperText: String {
        if healthKitExportState == .failed, let healthKitExportFailureMessage, !healthKitExportFailureMessage.isEmpty {
            return healthKitExportFailureMessage
        }

        if healthKitExportState == .exported && hasLocalChangesSinceHealthKitExport {
            return String(
                localized: "health.export_state_helper.saved_local_changes",
                defaultValue: "This tracked activity was saved to Apple Health earlier. Later edits now only live in WorkoutTracker and do not update the exported Health workout in this release."
            )
        }

        return healthKitExportState.helperText
    }

    var healthKitExportRecoveryText: String? {
        guard healthKitExportState == .failed else { return nil }
        return String(
            localized: "health.export_state_helper.retry_hint",
            defaultValue: "You can retry the Apple Health save from this summary after checking permissions."
        )
    }

    var allowsLocalDeletion: Bool {
        switch lifecycleState {
        case .completed, .discarded:
            return true
        case .planned, .inProgress, .paused:
            return false
        }
    }

    var localDeleteTitle: String {
        if healthKitExportState == .exported {
            return String(
                localized: "activities.delete.title.saved_to_health",
                defaultValue: "Delete local activity?"
            )
        }

        return String(
            localized: "activities.delete.title.default",
            defaultValue: "Delete activity?"
        )
    }

    var localDeleteMessage: String {
        if healthKitExportState == .exported {
            return String(
                localized: "activities.delete.message.saved_to_health",
                defaultValue: "Remove this tracked activity from WorkoutTracker only. The workout already saved to Apple Health will stay there."
            )
        }

        return String(
            localized: "activities.delete.message.default",
            defaultValue: "Remove this tracked activity from WorkoutTracker."
        )
    }

    var localDeleteActionTitle: String {
        String(localized: "activities.delete.action", defaultValue: "Delete activity")
    }

    var localDeleteFailureTitle: String {
        String(localized: "activities.delete.failure.title", defaultValue: "Could not delete activity")
    }

    var localDeleteFailureMessage: String {
        String(
            localized: "activities.delete.failure.message",
            defaultValue: "WorkoutTracker could not remove this activity right now. Please try again."
        )
    }
}
