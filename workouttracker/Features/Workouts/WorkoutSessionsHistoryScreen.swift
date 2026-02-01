import SwiftUI
import SwiftData

// File: workouttracker/Features/Workouts/WorkoutSessionsHistoryScreen.swift
//
// Why this exists:
// - WorkoutSessionsScreen needs a real “History” destination.
// - This stays decoupled from any older log/history UIs and only depends on WorkoutSession + WorkoutSessionScreen.

struct WorkoutSessionsHistoryScreen: View {
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    var body: some View {
        List {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "dumbbell",
                    description: Text("Start a routine to create your first session.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                SwiftUI.ForEach(sessions.indices, id: \.self) { idx in
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
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
