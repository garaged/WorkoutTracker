import SwiftUI
import SwiftData
import UIKit

struct TrackedActivitySessionScreen: View {
    let sessionID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)])
    private var trackedSessions: [TrackedActivitySession]

    @AppStorage(TrackedActivityHealthPreferences.autoSaveCompletedActivitiesKey)
    private var autoSaveToAppleHealth = false

    @State private var errorMessage: String?
    @State private var showDiscardConfirmation = false
    @State private var showFinishSummary = false
    @State private var lastPersistedRoutePointCount = 0
    @State private var healthExportBannerMessage: String?
    @State private var recoveryBannerMessage: String?
    @State private var routeCaptureBannerMessage: String?

    @StateObject private var routeRecorder = OutdoorRouteRecorder()
    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()

    private let recorder = TrackedActivityRecorder()
    private let summaryBuilder = TrackedActivitySummaryBuilder()
    private let exportCoordinator = TrackedActivityHealthExportCoordinator()
    private let recoveryPlanner = TrackedActivityRecoveryPlanner()

    private var session: TrackedActivitySession? {
        trackedSessions.first(where: { $0.id == sessionID })
    }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(for: session)
                        if let recoveryBannerMessage {
                            Text(recoveryBannerMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        if let routeCaptureBannerMessage {
                            Text(routeCaptureBannerMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        if let healthExportBannerMessage {
                            Text(healthExportBannerMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        liveMetricsSection(for: session)
                        routeSection(for: session)
                        notesSection(for: session)
                        actionSection(for: session)
                    }
                    .padding(16)
                }
                .navigationTitle(session.activityKind.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .alert(String(localized: "activities.session.update_error.title", defaultValue: "Could not update activity"), isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? String(localized: "common.unknown_error", defaultValue: "Unknown error"))
                }
                .confirmationDialog(
                    String(localized: "activities.session.discard.title", defaultValue: "Discard this tracked activity?"),
                    isPresented: $showDiscardConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "activities.session.discard.action", defaultValue: "Discard activity"), role: .destructive) {
                        discard(session)
                    }
                    Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
                } message: {
                    Text(String(localized: "activities.session.discard.message", defaultValue: "This removes the live activity session before it is completed."))
                }
                .navigationDestination(isPresented: $showFinishSummary) {
                    TrackedActivityFinishSummaryView(sessionID: sessionID)
//                    Text("Summary placeholder")
                }
                .onAppear {
                    let recoveryState = recoveryPlanner.recoveryState(for: session)
                    recoveryBannerMessage = recoveryBanner(for: session, state: recoveryState)
                    try? recorder.noteRecoveryOpened(session, context: modelContext)
                    WorkoutRemoteControlRouter.shared.focusTrackedActivity(sessionID: session.id)
                    lastPersistedRoutePointCount = session.routePointCount
                    routeRecorder.sync(with: session)
                    healthKitAuthorizationService.refresh()
                }
                .onDisappear {
//                    persistRouteIfNeeded(for: session, force: true)
//                    routeRecorder.stopRecording(resetSession: false)
//                    WorkoutRemoteControlRouter.shared.clearTrackedActivityFocus(sessionID: session.id)
                }
                .onChange(of: session.lifecycleStateRaw) { _, _ in
                    routeRecorder.sync(with: session)
                    if session.lifecycleState.isTerminal {
                        persistRouteIfNeeded(for: session, force: true)
                    }
                }
                .onChange(of: routeRecorder.capturedPoints.count) { oldCount, newCount in
                    guard newCount > 0 else { return }
                    if oldCount == 0 {
                        routeCaptureBannerMessage = String(
                            localized: "activities.session.route.capture_started_banner",
                            defaultValue: "Route capture is active. WorkoutTracker has started recording outdoor points for this activity."
                        )
                    }
                    if newCount - lastPersistedRoutePointCount >= 5 {
                        persistRouteIfNeeded(for: session, force: false)
                    }
                }
                .accessibilityIdentifier("TrackedActivitySession.Screen")
            } else {
                ContentUnavailableView(
                    String(localized: "activities.session.not_found.title", defaultValue: "Tracked activity not found"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(localized: "activities.session.not_found.message", defaultValue: "The selected tracked activity no longer exists."))
                )
            }
        }
    }

    @ViewBuilder
    private func header(for session: TrackedActivitySession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(session.activityKind.displayName, systemImage: session.activityKind.systemImage)
                .font(.title2.bold())

            Text(session.activityKind.helperText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                badge(text: session.lifecycleState.badgeText, color: badgeColor(for: session.lifecycleState))
                badge(text: session.environment.displayName, color: .secondary)
                if autoSaveToAppleHealth {
                    badge(text: String(localized: "activities.session.badge.auto_save", defaultValue: "Auto-save to Health"), color: .pink)
                }
            }
        }
    }

    @ViewBuilder
    private func liveMetricsSection(for session: TrackedActivitySession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let liveTotals = liveTotals(for: session, now: context.date)
            let metrics = summaryBuilder.metrics(for: session, liveTotals: liveTotals)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "activities.session.live_duration", defaultValue: "Live duration"))
                        .font(.headline)

                    Text(TrackedActivitySummaryBuilder.formatDuration(liveTotals.elapsedDuration))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(timerFooter(for: session))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "activities.session.current_metrics", defaultValue: "Current metrics"))
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(metrics.filter { $0.kind != .state }) { metric in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(metric.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(metric.value)
                                    .font(.headline)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }

                    if session.activityKind.supportsDistance {
                        Text(String(localized: "activities.session.metrics.refine_hint", defaultValue: "Distance, steps, and energy can be refined when you finish this activity. Outdoor route distance is prefilled when location data is available."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func routeSection(for session: TrackedActivitySession) -> some View {
        if session.activityKind.supportsDistance && session.environment == .outdoor {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "activities.session.route.title", defaultValue: "Outdoor route"))
                    .font(.headline)

                LabeledContent(String(localized: "activities.session.route.capture", defaultValue: "Route capture"), value: routeRecorder.captureState.title)
                LabeledContent(String(localized: "activities.session.route.captured_points", defaultValue: "Captured points"), value: String(max(session.routePointCount, routeRecorder.capturedPoints.count)))
                LabeledContent(String(localized: "activities.session.route.export_readiness", defaultValue: "Apple Health route"), value: session.liveRouteExportReadinessValue(using: healthKitAuthorizationService))

                if let liveRouteDistance = routeRecorder.derivedDistanceMeters ?? session.routeDistanceMeters {
                    LabeledContent(String(localized: "activities.session.route.approx_distance", defaultValue: "Approximate route distance"), value: formattedRouteDistance(liveRouteDistance))
                }

                Text(routeRecorder.captureState.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(session.liveRouteExportReadinessMessage(using: healthKitAuthorizationService))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if routeRecorder.canOpenSystemSettings {
                    Button(String(localized: "activities.session.open_location_settings", defaultValue: "Open Location Settings")) {
                        openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                } else if let actionTitle = healthKitAuthorizationService.routePermissionActionTitle,
                          healthKitAuthorizationService.routePermissionAction == .requestAuthorization {
                    Button(actionTitle) {
                        Task {
                            _ = try? await healthKitAuthorizationService.requestAuthorization()
                        }
                    }
                    .buttonStyle(.bordered)
                } else if let actionTitle = healthKitAuthorizationService.routePermissionActionTitle,
                          healthKitAuthorizationService.routePermissionAction == .openSettings {
                    Button(actionTitle) {
                        openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func liveTotals(for session: TrackedActivitySession, now: Date) -> TrackedActivityTotals {
        var totals = recorder.liveTotals(for: session, now: now)

        if session.activityKind.supportsDistance,
           let liveRouteDistance = routeRecorder.derivedDistanceMeters,
           liveRouteDistance > 0 {
            totals.distanceMeters = max(totals.distanceMeters ?? 0, liveRouteDistance)
        }

        return totals
    }

    @ViewBuilder
    private func notesSection(for session: TrackedActivitySession) -> some View {
        if let notes = session.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "activities.summary.notes.section", defaultValue: "Notes"))
                    .font(.headline)
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func actionSection(for session: TrackedActivitySession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack (spacing: 8) {
                if session.lifecycleState == .inProgress {
                    Button(String(localized: "common.pause", defaultValue: "Pause")) {
                        pause(session)
                    }
                    .buttonStyle(.bordered)

                    Button(String(localized: "common.finish", defaultValue: "Finish")) {
                        finish(session)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(String(localized: "common.discard", defaultValue: "Discard"), role: .destructive) {
                        showDiscardConfirmation = true
                    }
                    .buttonStyle(.bordered)
                } else if session.lifecycleState == .paused {
                    Button(String(localized: "common.resume", defaultValue: "Resume")) {
                        resume(session)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(String(localized: "common.finish", defaultValue: "Finish")) {
                        finish(session)
                    }
                    .buttonStyle(.bordered)

                    Button(String(localized: "common.discard", defaultValue: "Discard"), role: .destructive) {
                        showDiscardConfirmation = true
                    }
                    .buttonStyle(.bordered)
                } else if session.lifecycleState == .completed {
                    NavigationLink {
                        TrackedActivityFinishSummaryView(sessionID: session.id)
                    } label: {
                        Text(String(localized: "activities.session.open_summary", defaultValue: "Open summary"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else if session.lifecycleState == .discarded {
                    Button(String(localized: "common.close", defaultValue: "Close")) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pause(_ session: TrackedActivitySession) {
        do {
            persistRouteIfNeeded(for: session, force: true)
            try recorder.pause(session, context: modelContext)
            routeRecorder.sync(with: session)
            WorkoutRemoteControlRouter.shared.focusTrackedActivity(sessionID: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resume(_ session: TrackedActivitySession) {
        do {
            try recorder.resume(session, context: modelContext)
            routeRecorder.sync(with: session)
            WorkoutRemoteControlRouter.shared.focusTrackedActivity(sessionID: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finish(_ session: TrackedActivitySession) {
        do {
            persistRouteIfNeeded(for: session, force: true)
            try recorder.complete(session, context: modelContext)
            routeRecorder.stopRecording(resetSession: false)
            WorkoutRemoteControlRouter.shared.clearTrackedActivityFocus(sessionID: session.id)
            healthKitAuthorizationService.refresh()

            switch healthKitAuthorizationService.state {
            case .authorized:
                healthExportBannerMessage = autoSaveToAppleHealth
                    ? String(localized: "activities.session.health.auto_save_banner", defaultValue: "Apple Health auto-save will run after the summary opens when permission is available.")
                    : nil

            case .notRequested:
                healthExportBannerMessage = autoSaveToAppleHealth
                    ? String(localized: "activities.session.health.auto_save_requires_permission", defaultValue: "Apple Health auto-save is enabled, but permission has not been granted yet. You can enable it from the summary screen.")
                    : nil

            case .denied:
                healthExportBannerMessage = autoSaveToAppleHealth
                    ? String(localized: "activities.session.health.auto_save_denied", defaultValue: "Apple Health auto-save is enabled, but access is currently denied. You can review this from the summary screen.")
                    : nil

            case .unavailable:
                healthExportBannerMessage = autoSaveToAppleHealth
                    ? String(localized: "activities.session.health.auto_save_deferred_banner", defaultValue: "Apple Health auto-save is enabled, but export was deferred so finish stays fast and reliable. You can save from the summary screen.")
                    : nil            }

            showFinishSummary = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func discard(_ session: TrackedActivitySession) {
        do {
            persistRouteIfNeeded(for: session, force: true)
            try recorder.discard(session, context: modelContext)
            routeRecorder.stopRecording(resetSession: false)
            WorkoutRemoteControlRouter.shared.clearTrackedActivityFocus(sessionID: session.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recoveryBanner(for session: TrackedActivitySession, state: TrackedActivityRecoveryPlanner.RecoveryState) -> String? {
        switch state {
        case .paused:
            return String(localized: "activities.session.recovery_banner.paused", defaultValue: "WorkoutTracker reopened this tracked activity in its paused state. Resume when you are ready to continue.")
        case .interrupted:
            return String(localized: "activities.session.recovery_banner.interrupted", defaultValue: "WorkoutTracker recovered this tracked activity after an interruption so the timer, route, and summary can stay consistent.")
        case .staleNeedsPrompt, .staleSuppressed:
            let startedText = (session.startedAt ?? session.createdAt).formatted(date: .abbreviated, time: .shortened)
            return String(localized: "activities.session.recovery_banner.stale", defaultValue: "This tracked activity originally started on \(startedText). Review the final summary carefully when you finish.")
        case .live, .none:
            return nil
        }
    }

    private func persistRouteIfNeeded(for session: TrackedActivitySession, force: Bool) {
        let currentPointCount = routeRecorder.capturedPoints.count
        guard currentPointCount > 0 else { return }
        if force {
            guard currentPointCount != lastPersistedRoutePointCount else { return }
        } else {
            guard currentPointCount - lastPersistedRoutePointCount >= 5 else { return }
        }

        do {
            try recorder.updateCapturedRoute(
                for: session,
                routePoints: routeRecorder.capturedPoints,
                derivedDistanceMeters: routeRecorder.derivedDistanceMeters,
                context: modelContext
            )
            lastPersistedRoutePointCount = currentPointCount
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formattedRouteDistance(_ meters: Double) -> String {
        let kilometers = meters / 1_000
        return String(format: String(localized: "activities.distance.kilometers", defaultValue: "%@ km"), kilometers.formatted(.number.precision(.fractionLength(0...2))))
    }

    private func timerFooter(for session: TrackedActivitySession) -> String {
        switch session.lifecycleState {
        case .inProgress:
            return String(localized: "activities.session.footer.in_progress", defaultValue: "The timer is live. Finish when you are done, then add any available metrics to the summary.")
        case .paused:
            return String(localized: "activities.session.footer.paused", defaultValue: "This tracked activity is paused. Resume to continue timing or finish to save what you already recorded.")
        case .completed:
            if autoSaveToAppleHealth {
                return String(localized: "activities.session.footer.completed_auto_save", defaultValue: "This tracked activity is complete. Review the summary while WorkoutTracker saves to Apple Health when possible.")
            }
            return String(localized: "activities.session.footer.completed", defaultValue: "This tracked activity is complete. You can review and refine the final summary.")
        case .discarded:
            return String(localized: "activities.session.footer.discarded", defaultValue: "This tracked activity was discarded.")
        case .planned:
            return String(localized: "activities.session.footer.planned", defaultValue: "This tracked activity has not started yet.")
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private func badgeColor(for state: TrackedActivityLifecycleState) -> Color {
        switch state {
        case .inProgress:
            return .green
        case .paused:
            return .orange
        case .completed:
            return .blue
        case .discarded, .planned:
            return .secondary
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
