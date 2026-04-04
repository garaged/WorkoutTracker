import SwiftUI
import SwiftData

struct WorkoutSessionsHistoryScreen: View {
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)])
    private var trackedSessions: [TrackedActivitySession]

    private var activeTrackedSessions: [TrackedActivitySession] {
        trackedSessions.filter { $0.lifecycleState == .inProgress || $0.lifecycleState == .paused }
    }

    private var finishedTrackedSessions: [TrackedActivitySession] {
        trackedSessions.filter { $0.lifecycleState == .completed || $0.lifecycleState == .discarded }
    }

    var body: some View {
        List {
            if sessions.isEmpty && trackedSessions.isEmpty {
                ContentUnavailableView(
                    String(localized: "history.empty.title", defaultValue: "No history yet"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(String(localized: "history.empty.message", defaultValue: "Complete a workout or tracked activity to see it here."))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                if !activeTrackedSessions.isEmpty {
                    Section(String(localized: "history.section.active_tracked", defaultValue: "Resume tracked activities")) {
                        ForEach(activeTrackedSessions) { session in
                            NavigationLink {
                                TrackedActivitySessionScreen(sessionID: session.id)
                            } label: {
                                TrackedActivityHistoryRow(session: session)
                            }
                        }
                    }
                }

                if !finishedTrackedSessions.isEmpty {
                    Section(String(localized: "history.section.tracked_activities", defaultValue: "Tracked activities")) {
                        ForEach(finishedTrackedSessions) { session in
                            NavigationLink {
                                TrackedActivityFinishSummaryView(sessionID: session.id)
                            } label: {
                                TrackedActivityHistoryRow(session: session)
                            }
                        }
                    }
                }

                if !sessions.isEmpty {
                    Section(String(localized: "history.section.strength_sessions", defaultValue: "Strength sessions")) {
                        ForEach(sessions.indices, id: \.self) { idx in
                            let s = sessions[idx]
                            NavigationLink {
                                WorkoutSessionScreen(session: s)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                        .font(.body.weight(.semibold))
                                    Text(s.startedAt.formatted(.dateTime.hour().minute()))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "history.title", defaultValue: "History"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
