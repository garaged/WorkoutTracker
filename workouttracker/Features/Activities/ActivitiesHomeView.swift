import SwiftUI
import SwiftData

struct ActivitiesHomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)])
    private var trackedSessions: [TrackedActivitySession]

    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()
    @State private var sessionPendingDeletion: TrackedActivitySession?
    @State private var deleteFailureMessage: String?

    private let recorder = TrackedActivityRecorder()

    private var activeSessions: [TrackedActivitySession] {
        trackedSessions.filter { $0.lifecycleState == .inProgress || $0.lifecycleState == .paused }
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

    var body: some View {
        List {
            if let recoverySession = activeSessions.first {
                Section {
                    NavigationLink {
                        TrackedActivitySessionScreen(sessionID: recoverySession.id)
                    } label: {
                        recoveryCard(for: recoverySession)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(String(localized: "activities.section.recovery", defaultValue: "Recovery"))
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

            if !activeSessions.isEmpty {
                Section(String(localized: "activities.section.active", defaultValue: "Active")) {
                    ForEach(activeSessions) { session in
                        NavigationLink {
                            TrackedActivitySessionScreen(sessionID: session.id)
                        } label: {
                            TrackedActivitySessionRow(session: session)
                        }
                    }
                }
            }

            if !recentSessions.isEmpty {
                Section(String(localized: "activities.section.recent", defaultValue: "Recent")) {
                    ForEach(recentSessions) { session in
                        NavigationLink {
                            TrackedActivityFinishSummaryView(sessionID: session.id)
                        } label: {
                            TrackedActivitySessionRow(session: session)
                        }
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
        .alert(
            String(localized: "activities.delete.failure.title", defaultValue: "Could not delete activity"),
            isPresented: Binding(
                get: { deleteFailureMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteFailureMessage = nil
                    }
                }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {
                deleteFailureMessage = nil
            }
        } message: {
            Text(deleteFailureMessage ?? String(localized: "activities.delete.failure.message", defaultValue: "WorkoutTracker could not remove this activity right now. Please try again."))
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

            Text(healthKitAuthorizationService.state.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }


    private func recoveryCard(for session: TrackedActivitySession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                session.lifecycleState == .paused
                    ? String(localized: "activities.recovery.paused_title", defaultValue: "Resume your paused activity")
                    : String(localized: "activities.recovery.live_title", defaultValue: "Return to your active activity"),
                systemImage: session.activityKind.systemImage
            )
            .font(.headline)

            Text(String(localized: "activities.recovery.message", defaultValue: "WorkoutTracker kept this tracked activity open so you can resume it honestly after an interruption or relaunch."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(session.activityKind.displayName)
                    .font(.caption.weight(.medium))
                Text(session.lifecycleState.badgeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var healthStatusColor: Color {
        switch healthKitAuthorizationService.state {
        case .authorized:
            return .green
        case .denied:
            return .orange
        case .notRequested, .unavailable:
            return .secondary
        }
    }
    
    private func recentSortDate(for session: TrackedActivitySession) -> Date {
        session.endedAt ?? session.updatedAt ?? session.startedAt ?? session.createdAt
    }

    private func delete(_ session: TrackedActivitySession) {
        do {
            try recorder.delete(session, context: modelContext)
            sessionPendingDeletion = nil
        } catch {
            deleteFailureMessage = error.localizedDescription
        }
    }
}

private struct TrackedActivitySessionRow: View {
    let session: TrackedActivitySession

    private let summaryBuilder = TrackedActivitySummaryBuilder()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Label(session.activityKind.displayName, systemImage: session.activityKind.systemImage)
                    .font(.headline)

                Spacer(minLength: 8)

                Text(session.lifecycleState.badgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badgeColor)
            }

            if let startedAt = session.startedAt {
                Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

    private var badgeColor: Color {
        switch session.lifecycleState {
        case .inProgress:
            return .green
        case .paused:
            return .orange
        case .completed:
            return .blue
        case .discarded:
            return .secondary
        case .planned:
            return .secondary
        }
    }
}
