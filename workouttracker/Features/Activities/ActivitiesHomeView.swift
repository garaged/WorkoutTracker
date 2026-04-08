import SwiftUI
import SwiftData

struct ActivitiesHomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)])
    private var trackedSessions: [TrackedActivitySession]

    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()
    @State private var sessionPendingDeletion: TrackedActivitySession?
    @State private var recoveryPromptSession: TrackedActivitySession?
    @State private var destination: ActivitiesDestination?
    @State private var errorMessage: String?

    private let recorder = TrackedActivityRecorder()
    private let recoveryPlanner = TrackedActivityRecoveryPlanner()

    private enum ActivitiesDestination: Identifiable, Hashable {
        case live(UUID)
        case summary(UUID)

        var id: String {
            switch self {
            case .live(let id): return "live-\(id.uuidString)"
            case .summary(let id): return "summary-\(id.uuidString)"
            }
        }
    }

    private var activeSessions: [TrackedActivitySession] {
        trackedSessions.filter { $0.lifecycleState == .inProgress || $0.lifecycleState == .paused }
    }

    private var prioritizedActiveSessions: [TrackedActivitySession] {
        recoveryPlanner.sortedRecoverySessions(activeSessions)
    }

    private var recentSessions: [TrackedActivitySession] {
        trackedSessions
            .filter { session in
                switch session.lifecycleState {
                case .inProgress, .paused:
                    return false
                case .completed, .discarded:
                    return true
                case .planned:
                    return session.endedAt != nil
                }
            }
            .sorted { lhs, rhs in
                recentSortDate(for: lhs) > recentSortDate(for: rhs)
            }
            .prefix(12)
            .map { $0 }
    }

    private var healthFollowUpSessions: [TrackedActivitySession] {
        recoveryPlanner.sortedHealthFollowUpSessions(recentSessions)
    }

    private var primaryRecoverySession: TrackedActivitySession? {
        prioritizedActiveSessions.first
    }

    private var primaryHealthFollowUpSession: TrackedActivitySession? {
        healthFollowUpSessions.first
    }

    var body: some View {
        List {
            if let recoverySession = primaryRecoverySession {
                Section {
                    Button {
                        handleActiveSessionTap(recoverySession)
                    } label: {
                        recoveryCard(
                            for: recoverySession,
                            state: recoveryPlanner.recoveryState(for: recoverySession)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Activities.Recovery.Card")
                } header: {
                    Text(String(localized: "activities.section.recovery", defaultValue: "Recovery"))
                }
                .listRowBackground(Color.clear)
            }

            if let followUpSession = primaryHealthFollowUpSession {
                Section {
                    Button {
                        destination = .summary(followUpSession.id)
                    } label: {
                        healthFollowUpCard(
                            for: followUpSession,
                            state: recoveryPlanner.healthFollowUpState(for: followUpSession)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Activities.HealthFollowUp.Card")
                } header: {
                    Text(String(localized: "activities.section.health_follow_up", defaultValue: "Health follow-up"))
                }
                .listRowBackground(Color.clear)
            }

            Section {
                NavigationLink {
                    TrackedActivityStartView()
                } label: {
                    activityStartCard
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(Color.clear)

            Section {
                NavigationLink {
                    HealthPermissionsView()
                } label: {
                    healthStatusCard
                }
                .buttonStyle(.plain)
            } header: {
                Text(String(localized: "activities.health.title", defaultValue: "Apple Health"))
            }
            .listRowBackground(Color.clear)

            if !prioritizedActiveSessions.isEmpty {
                Section(String(localized: "activities.section.active", defaultValue: "Active")) {
                    ForEach(prioritizedActiveSessions) { session in
                        Button {
                            handleActiveSessionTap(session)
                        } label: {
                            TrackedActivitySessionRow(
                                session: session,
                                recoveryState: recoveryPlanner.recoveryState(for: session),
                                healthFollowUpState: .none
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !recentSessions.isEmpty {
                Section(String(localized: "activities.section.recent", defaultValue: "Recent")) {
                    ForEach(recentSessions) { session in
                        Button {
                            destination = .summary(session.id)
                        } label: {
                            TrackedActivitySessionRow(
                                session: session,
                                recoveryState: .none,
                                healthFollowUpState: recoveryPlanner.healthFollowUpState(for: session)
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if session.allowsLocalDeletion {
                                Button(role: .destructive) {
                                    sessionPendingDeletion = session
                                } label: {
                                    Label(session.localDeleteActionTitle, systemImage: "trash")
                                }
                                .accessibilityIdentifier("TrackedActivity.RecentRow.Delete.\(session.id.uuidString)")
                            }
                        }
                        .contextMenu {
                            if session.allowsLocalDeletion {
                                Button(role: .destructive) {
                                    sessionPendingDeletion = session
                                } label: {
                                    Label(session.localDeleteActionTitle, systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            if trackedSessions.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "activities.empty.title", defaultValue: "No tracked activities yet"),
                        systemImage: "figure.walk.motion",
                        description: Text(String(localized: "activities.empty.message", defaultValue: "Start a walk, run, hike, or yoga session here. Tracked activities stay separate from your strength workouts."))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(String(localized: "activities.title", defaultValue: "Activities"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    TrackedActivityStartView()
                } label: {
                    Label(String(localized: "activities.action.start", defaultValue: "Start"), systemImage: "plus")
                }
            }
        }
        .task {
            healthKitAuthorizationService.refresh()
        }
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .live(let id):
                TrackedActivitySessionScreen(sessionID: id)
            case .summary(let id):
                TrackedActivityFinishSummaryView(sessionID: id)
            }
        }
        .confirmationDialog(
            sessionPendingDeletion?.localDeleteTitle ?? String(localized: "activities.delete.title.default", defaultValue: "Delete activity?"),
            isPresented: Binding(
                get: { sessionPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        sessionPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let sessionPendingDeletion {
                Button(sessionPendingDeletion.localDeleteActionTitle, role: .destructive) {
                    delete(sessionPendingDeletion)
                }
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                sessionPendingDeletion = nil
            }
        } message: {
            Text(sessionPendingDeletion?.localDeleteMessage ?? "")
        }
        .confirmationDialog(
            recoveryPromptSession?.recoveryPromptTitle ?? String(localized: "activities.recovery.prompt.title", defaultValue: "Review previous activity?"),
            isPresented: Binding(
                get: { recoveryPromptSession != nil },
                set: { isPresented in
                    if !isPresented {
                        recoveryPromptSession = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let recoveryPromptSession {
                Button(recoveryPromptSession.recoveryResumeActionTitle) {
                    resumeFromRecovery(recoveryPromptSession)
                }
                Button(String(localized: "activities.recovery.keep_for_later", defaultValue: "Keep for later")) {
                    keepForLater(recoveryPromptSession)
                }
                Button(String(localized: "activities.recovery.discard", defaultValue: "Discard activity"), role: .destructive) {
                    discard(recoveryPromptSession)
                }
                .accessibilityIdentifier("Activities.Recovery.Discard")
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                recoveryPromptSession = nil
            }
        } message: {
            Text(recoveryPromptSession?.recoveryPromptMessage ?? "")
        }
        .alert(
            String(localized: "activities.session.update_error.title", defaultValue: "Could not update activity"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? String(localized: "common.unknown_error", defaultValue: "Unknown error"))
        }
    }

    private var activityStartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "activities.start.card.title", defaultValue: "Tracked activities"), systemImage: "figure.walk.motion")
                .font(.headline)

            Text(String(localized: "activities.start.card.message", defaultValue: "Start a walk, run, hike, or yoga session. Duration is tracked live, and activity-specific metrics can be added when you finish."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach([TrackedActivityKind.walking, .running, .hiking, .yoga], id: \.self) { kind in
                    Label(kind.displayName, systemImage: kind.systemImage)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
            }
            .lineLimit(1)
        }
        .padding(.vertical, 8)
    }

    private var healthStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Label(String(localized: "activities.health.title", defaultValue: "Apple Health"), systemImage: "heart.text.square")
                    .font(.headline)
                Spacer(minLength: 8)
                Text(healthKitAuthorizationService.state.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(healthStatusColor)
            }

            Text(healthKitAuthorizationService.statusSummaryMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }

    private func recoveryCard(for session: TrackedActivitySession, state: TrackedActivityRecoveryPlanner.RecoveryState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(session.recoveryCardTitle(for: state), systemImage: session.activityKind.systemImage)
                .font(.headline)

            Text(session.recoveryCardMessage(for: state))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(session.activityKind.displayName)
                    .font(.caption.weight(.medium))
                Text(session.recoveryBadgeText(for: state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func healthFollowUpCard(
        for session: TrackedActivitySession,
        state: TrackedActivityRecoveryPlanner.HealthFollowUpState
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(session.healthFollowUpTitle(for: state), systemImage: "heart.text.square")
                .font(.headline)

            Text(session.healthFollowUpMessage(for: state))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(session.activityKind.displayName)
                    .font(.caption.weight(.medium))
                if let endedAt = session.endedAt {
                    Text(endedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var healthStatusColor: Color {
        switch healthKitAuthorizationService.state {
        case .authorized:
            return healthKitAuthorizationService.routeState == .denied ? .orange : .green
        case .denied:
            return .orange
        case .notRequested, .unavailable:
            return .secondary
        }
    }

    private func recentSortDate(for session: TrackedActivitySession) -> Date {
        session.endedAt ?? session.updatedAt ?? session.startedAt ?? session.createdAt
    }

    private func handleActiveSessionTap(_ session: TrackedActivitySession) {
        let state = recoveryPlanner.recoveryState(for: session)
        if state.shouldShowPrompt {
            recoveryPromptSession = session
            return
        }

        if session.lifecycleState == .paused {
            resumeAndOpen(session)
        } else {
            openLiveSession(session)
        }
    }

    private func openLiveSession(_ session: TrackedActivitySession) {
        do {
            try recorder.noteRecoveryOpened(session, context: modelContext)
            destination = .live(session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resumeAndOpen(_ session: TrackedActivitySession) {
        do {
            try recorder.resume(session, context: modelContext)
            destination = .live(session.id)
            recoveryPromptSession = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func keepForLater(_ session: TrackedActivitySession) {
        do {
            try recorder.keepForLater(session, context: modelContext)
            recoveryPromptSession = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func discard(_ session: TrackedActivitySession) {
        do {
            try recorder.discard(session, context: modelContext)
            recoveryPromptSession = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resumeFromRecovery(_ session: TrackedActivitySession) {
        if session.lifecycleState == .paused {
            resumeAndOpen(session)
        } else {
            openLiveSession(session)
            recoveryPromptSession = nil
        }
    }

    private func delete(_ session: TrackedActivitySession) {
        do {
            try recorder.delete(session, context: modelContext)
            sessionPendingDeletion = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TrackedActivitySessionRow: View {
    let session: TrackedActivitySession
    let recoveryState: TrackedActivityRecoveryPlanner.RecoveryState
    let healthFollowUpState: TrackedActivityRecoveryPlanner.HealthFollowUpState

    private let summaryBuilder = TrackedActivitySummaryBuilder()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Label(session.activityKind.displayName, systemImage: session.activityKind.systemImage)
                    .font(.headline)

                Spacer(minLength: 8)

                Text(badgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badgeColor)
            }

            if let startedAt = session.startedAt {
                Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let followUpMessage {
                Text(followUpMessage)
                    .font(.footnote)
                    .foregroundStyle(followUpColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let metrics = summaryBuilder.metrics(for: session)
                .filter { $0.kind != .state }
                .prefix(3)

            if !metrics.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(metrics)) { metric in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(metric.value)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var badgeText: String {
        switch recoveryState {
        case .staleNeedsPrompt, .staleSuppressed:
            return String(localized: "activities.recovery.badge.previous_day", defaultValue: "Previous day")
        case .interrupted:
            return String(localized: "activities.recovery.badge.interrupted", defaultValue: "Interrupted")
        case .paused:
            return String(localized: "activities.lifecycle.paused", defaultValue: "Paused")
        case .live, .none:
            return session.lifecycleState.badgeText
        }
    }

    private var badgeColor: Color {
        switch recoveryState {
        case .staleNeedsPrompt, .staleSuppressed, .paused, .interrupted:
            return .orange
        case .live:
            return .green
        case .none:
            switch session.lifecycleState {
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
    }

    private var followUpMessage: String? {
        switch healthFollowUpState {
        case .none:
            switch recoveryState {
            case .staleNeedsPrompt:
                return String(localized: "activities.recovery.row.previous_day", defaultValue: "Previous-day activity needs a resume, keep-for-later, or discard decision.")
            case .staleSuppressed:
                return String(localized: "activities.recovery.row.suppressed", defaultValue: "Kept for later today. You can still reopen it directly.")
            case .interrupted:
                return String(localized: "activities.recovery.row.interrupted", defaultValue: "WorkoutTracker kept this live activity open after an interruption.")
            case .paused:
                return String(localized: "activities.recovery.row.paused", defaultValue: "Paused and ready to continue when you return.")
            case .live, .none:
                return nil
            }
        case .exportPending:
            return String(localized: "activities.health.follow_up.pending", defaultValue: "Apple Health save is still pending. Open the summary to verify the final status.")
        case .exportFailed:
            return String(localized: "activities.health.follow_up.failed", defaultValue: "Apple Health save failed. Open the summary to retry or review permissions.")
        case .savedWithLocalChanges:
            return String(localized: "activities.health.follow_up.local_changes", defaultValue: "WorkoutTracker saved later edits locally only. Open the summary to review what differs from Apple Health.")
        }
    }

    private var followUpColor: Color {
        switch healthFollowUpState {
        case .exportFailed:
            return .orange
        case .exportPending:
            return .secondary
        case .savedWithLocalChanges:
            return .secondary
        case .none:
            switch recoveryState {
            case .staleNeedsPrompt, .staleSuppressed, .paused, .interrupted:
                return .secondary
            case .live, .none:
                return .secondary
            }
        }
    }
}
