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


extension TrackedActivitySession {
    var recoveryResumeActionTitle: String {
        if lifecycleState == .paused {
            return String(localized: "activities.recovery.resume_action", defaultValue: "Resume activity")
        }
        return String(localized: "activities.recovery.open_action", defaultValue: "Open activity")
    }

    var recoveryPromptTitle: String {
        String(localized: "activities.recovery.prompt.title", defaultValue: "Review previous activity?")
    }

    var recoveryPromptMessage: String {
        let formattedDay = (startedAt ?? createdAt).formatted(date: .abbreviated, time: .shortened)
        return String(
            localized: "activities.recovery.prompt.message",
            defaultValue: "This tracked activity started on \(formattedDay). Resume it now, keep it for later today, or discard it so your recovery state stays honest."
        )
    }

    func recoveryCardTitle(for state: TrackedActivityRecoveryPlanner.RecoveryState) -> String {
        switch state {
        case .paused:
            return String(localized: "activities.recovery.paused_title", defaultValue: "Resume your paused activity")
        case .interrupted:
            return String(localized: "activities.recovery.interrupted_title", defaultValue: "Return to your interrupted activity")
        case .staleNeedsPrompt, .staleSuppressed:
            return String(localized: "activities.recovery.stale_title", defaultValue: "Review your previous activity")
        case .live, .none:
            return String(localized: "activities.recovery.live_title", defaultValue: "Return to your active activity")
        }
    }

    func recoveryCardMessage(for state: TrackedActivityRecoveryPlanner.RecoveryState) -> String {
        switch state {
        case .paused:
            return String(localized: "activities.recovery.paused_message", defaultValue: "WorkoutTracker kept this paused tracked activity ready so you can continue honestly after a relaunch or interruption.")
        case .interrupted:
            return String(localized: "activities.recovery.interrupted_message", defaultValue: "WorkoutTracker kept this tracked activity open after an interruption so the elapsed time and route can stay consistent when you come back.")
        case .staleNeedsPrompt:
            return String(localized: "activities.recovery.stale_message", defaultValue: "This tracked activity started on a previous day. Resume it now, keep it for later today, or discard it so unfinished activity data stays trustworthy.")
        case .staleSuppressed:
            return String(localized: "activities.recovery.suppressed_message", defaultValue: "You already chose to keep this previous-day activity for later today. WorkoutTracker will let you reopen it directly until you decide what to do.")
        case .live, .none:
            return String(localized: "activities.recovery.message", defaultValue: "WorkoutTracker kept this tracked activity open so you can resume it honestly after an interruption or relaunch.")
        }
    }

    func recoveryBadgeText(for state: TrackedActivityRecoveryPlanner.RecoveryState) -> String {
        switch state {
        case .staleNeedsPrompt, .staleSuppressed:
            return String(localized: "activities.recovery.badge.previous_day", defaultValue: "Previous day")
        case .interrupted:
            return String(localized: "activities.recovery.badge.interrupted", defaultValue: "Interrupted")
        case .paused:
            return String(localized: "activities.lifecycle.paused", defaultValue: "Paused")
        case .live, .none:
            return lifecycleState.badgeText
        }
    }

    func healthFollowUpTitle(for state: TrackedActivityRecoveryPlanner.HealthFollowUpState) -> String {
        switch state {
        case .exportPending:
            return String(localized: "activities.health.follow_up.card.pending_title", defaultValue: "Finish Apple Health save")
        case .exportFailed:
            return String(localized: "activities.health.follow_up.card.failed_title", defaultValue: "Retry Apple Health save")
        case .savedWithLocalChanges:
            return String(localized: "activities.health.follow_up.card.local_changes_title", defaultValue: "Review local-only edits")
        case .none:
            return String(localized: "activities.health.title", defaultValue: "Apple Health")
        }
    }

    func healthFollowUpMessage(for state: TrackedActivityRecoveryPlanner.HealthFollowUpState) -> String {
        switch state {
        case .exportPending:
            return String(localized: "activities.health.follow_up.card.pending_message", defaultValue: "WorkoutTracker still shows this save as pending. Open the summary to verify the final Health status before you move on.")
        case .exportFailed:
            return String(localized: "activities.health.follow_up.card.failed_message", defaultValue: "The last Apple Health save attempt failed. Open the summary to retry after checking permissions and route availability.")
        case .savedWithLocalChanges:
            return String(localized: "activities.health.follow_up.card.local_changes_message", defaultValue: "This workout was saved to Apple Health earlier, but later edits now only live inside WorkoutTracker. Open the summary to review the difference honestly.")
        case .none:
            return healthKitExportHelperText
        }
    }
}

extension TrackedActivitySession {
    var healthKitRouteAttachmentDisplayName: String {
        switch healthKitRouteAttachmentState {
        case .unknown:
            return String(localized: "activities.health.route_attachment.unknown", defaultValue: "Unknown")
        case .notApplicable:
            return String(localized: "activities.health.route_attachment.not_applicable", defaultValue: "Not applicable")
        case .noRouteData:
            return String(localized: "activities.health.route_attachment.no_route_data", defaultValue: "No route data")
        case .attached:
            return String(localized: "activities.health.route_attachment.attached", defaultValue: "Attached")
        case .failed:
            return String(localized: "activities.health.route_attachment.failed", defaultValue: "Could not attach")
        }
    }

    var healthKitRouteAttachmentHelperText: String {
        if healthKitRouteAttachmentState == .failed,
           let healthKitRouteAttachmentFailureMessage,
           !healthKitRouteAttachmentFailureMessage.isEmpty {
            return healthKitRouteAttachmentFailureMessage
        }

        switch healthKitRouteAttachmentState {
        case .unknown:
            return String(
                localized: "activities.health.route_attachment.helper.unknown",
                defaultValue: "Route attachment outcome is not available yet."
            )
        case .notApplicable:
            return String(
                localized: "activities.health.route_attachment.helper.not_applicable",
                defaultValue: "This activity type does not attach an outdoor route in Apple Health."
            )
        case .noRouteData:
            return String(
                localized: "activities.health.route_attachment.helper.no_route_data",
                defaultValue: "The workout saved, but there were no captured route points to attach."
            )
        case .attached:
            return String(
                localized: "activities.health.route_attachment.helper.attached",
                defaultValue: "The captured outdoor route was attached when this workout was saved to Apple Health."
            )
        case .failed:
            return String(
                localized: "activities.health.route_attachment.helper.failed",
                defaultValue: "The workout saved, but the outdoor route could not be attached."
            )
        }
    }
}

extension TrackedActivitySession {
    var capturedRouteDisplayValue: String {
        guard hasRecordedRoute else {
            return String(localized: "activities.health.route_attachment.not_captured", defaultValue: "No route captured")
        }

        return String(
            format: String(localized: "activities.health.route_points", defaultValue: "%lld points"),
            Int64(routePointCount)
        )
    }

    @MainActor
    func routeAttachmentReadinessValue(using healthAuthorizationService: HealthKitAuthorizationService) -> String {
        guard environment == .outdoor, activityKind.supportsDistance else {
            return String(localized: "activities.health.not_available", defaultValue: "Not available")
        }

        guard hasRecordedRoute else {
            return String(localized: "activities.health.route_attachment.not_captured", defaultValue: "No route captured")
        }

        if healthKitExportState == .pending {
            return String(localized: "activities.health.route_attachment.pending", defaultValue: "Waiting to save")
        }

        if healthKitExportState == .exported {
            return healthKitRouteAttachmentDisplayName
        }

        switch healthAuthorizationService.routeState {
        case .authorized:
            return String(localized: "activities.health.route_attachment.ready", defaultValue: "Ready to attach")
        case .notRequested, .denied:
            return String(localized: "activities.health.route_attachment.permission_needed", defaultValue: "Permission needed")
        case .unavailable:
            return String(localized: "activities.health.route_attachment.unavailable", defaultValue: "Unavailable")
        }
    }

    @MainActor
    func routeAttachmentReadinessMessage(using healthAuthorizationService: HealthKitAuthorizationService) -> String {
        guard environment == .outdoor, activityKind.supportsDistance else {
            return String(
                localized: "activities.health.route_attachment.message.not_applicable",
                defaultValue: "This activity type does not attach an outdoor route in Apple Health."
            )
        }

        guard hasRecordedRoute else {
            return String(
                localized: "activities.health.route_attachment.message.not_captured",
                defaultValue: "No outdoor route points were captured for this activity, so Apple Health can only save the workout."
            )
        }

        if healthKitExportState == .pending {
            return String(
                localized: "activities.health.route_attachment.message.pending",
                defaultValue: "WorkoutTracker still needs to finish saving this workout before the captured route can be attached in Apple Health."
            )
        }

        if healthKitExportState == .exported {
            return healthKitRouteAttachmentHelperText
        }

        switch healthAuthorizationService.routeState {
        case .authorized:
            return String(
                localized: "activities.health.route_attachment.message.ready",
                defaultValue: "This activity captured route points locally. Apple Health route attachment is ready the next time you save the workout."
            )
        case .notRequested:
            return String(
                localized: "activities.health.route_attachment.message.not_requested",
                defaultValue: "This activity captured route points locally, but Apple Health route access still needs to be granted before the route can be attached during export."
            )
        case .denied:
            return String(
                localized: "activities.health.route_attachment.message.denied",
                defaultValue: "This activity captured route points locally, but Apple Health route access is currently blocked until it is re-enabled in Settings."
            )
        case .unavailable:
            return String(
                localized: "activities.health.route_attachment.message.unavailable",
                defaultValue: "This activity captured route points locally, but Apple Health route export is unavailable on this device."
            )
        }
    }

    @MainActor
    func liveRouteExportReadinessValue(using healthAuthorizationService: HealthKitAuthorizationService) -> String {
        guard environment == .outdoor, activityKind.supportsDistance else {
            return String(localized: "activities.health.not_available", defaultValue: "Not available")
        }

        switch healthAuthorizationService.routeState {
        case .authorized:
            return String(localized: "activities.session.route.export_readiness.ready", defaultValue: "Ready when captured")
        case .notRequested, .denied:
            return String(localized: "activities.health.route_attachment.permission_needed", defaultValue: "Permission needed")
        case .unavailable:
            return String(localized: "activities.health.route_attachment.unavailable", defaultValue: "Unavailable")
        }
    }

    @MainActor
    func liveRouteExportReadinessMessage(using healthAuthorizationService: HealthKitAuthorizationService) -> String {
        guard environment == .outdoor, activityKind.supportsDistance else {
            return String(
                localized: "activities.session.route.export_readiness.not_applicable",
                defaultValue: "This activity type does not attach an outdoor route in Apple Health."
            )
        }

        switch healthAuthorizationService.routeState {
        case .authorized:
            return String(
                localized: "activities.session.route.export_readiness.message.ready",
                defaultValue: "If route points are captured during this activity, Apple Health route attachment is ready when you save the workout."
            )
        case .notRequested:
            return String(
                localized: "activities.session.route.export_readiness.message.not_requested",
                defaultValue: "Route points can still be captured locally now, but Apple Health route access still needs to be granted before they can be attached during export."
            )
        case .denied:
            return String(
                localized: "activities.session.route.export_readiness.message.denied",
                defaultValue: "Route points can still be captured locally now, but Apple Health route access is currently blocked until it is re-enabled in Settings."
            )
        case .unavailable:
            return String(
                localized: "activities.session.route.export_readiness.message.unavailable",
                defaultValue: "Route points can still stay local in WorkoutTracker, but Apple Health route export is unavailable on this device."
            )
        }
    }
}
