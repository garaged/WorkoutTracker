import Foundation

extension TrackedActivityKind {
    var displayName: String {
        switch self {
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .hiking:
            return "Hiking"
        case .yoga:
            return "Yoga"
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
            return "Start walk"
        case .running:
            return "Start run"
        case .hiking:
            return "Start hike"
        case .yoga:
            return "Start yoga"
        }
    }

    var helperText: String {
        switch self {
        case .walking:
            return "Duration is always tracked. Distance, steps, and energy can be added after you finish."
        case .running:
            return "Duration is always tracked. Distance, energy, and steps can be added after you finish."
        case .hiking:
            return "Duration is always tracked. Distance, energy, and steps can be added after you finish."
        case .yoga:
            return "Duration is always tracked. Energy and notes can be added after you finish."
        }
    }
}

extension ActivityEnvironment {
    var displayName: String {
        switch self {
        case .indoor:
            return "Indoor"
        case .outdoor:
            return "Outdoor"
        case .unspecified:
            return "Automatic"
        }
    }
}

extension TrackedActivityLifecycleState {
    var badgeText: String {
        switch self {
        case .planned:
            return "Planned"
        case .inProgress:
            return "Live"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .discarded:
            return "Discarded"
        }
    }
}

extension HealthKitExportState {
    var displayName: String {
        switch self {
        case .notRequested:
            return "Not saved"
        case .notAvailable:
            return "Unavailable"
        case .pending:
            return "Saving"
        case .exported:
            return "Saved"
        case .failed:
            return "Save failed"
        }
    }

    var helperText: String {
        switch self {
        case .notRequested:
            return "This tracked activity has not been saved to Apple Health yet."
        case .notAvailable:
            return "Apple Health is not available on this device."
        case .pending:
            return "WorkoutTracker is currently saving this tracked activity to Apple Health."
        case .exported:
            return "This tracked activity was saved to Apple Health. Later edits in WorkoutTracker do not update the already-saved Health workout in this release."
        case .failed:
            return "The last Apple Health save attempt did not complete. You can retry after checking permissions."
        }
    }
}
