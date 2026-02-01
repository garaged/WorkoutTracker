import SwiftUI
import SwiftData

// File: workouttracker/Features/Workouts/WorkoutSessionsScreen.swift
//
// Fix:
// - `ActionRow` was referenced but not in scope (it likely existed in another file or was `private`).
// - This screen is now self-contained by defining its own `ActionRow`.
//
// Why this is the right approach:
// - Prevents accidental cross-feature coupling (Progress/Workouts shouldn’t depend on each other’s UI helpers).
// - Keeps this file compiling even if you refactor other screens later.
//
// Current wiring provided by this screen:
// - Start a Workout -> RoutinesScreen
// - Workout History -> WorkoutSessionsHistoryScreen
// - Continue -> opens latest session (safe default: doesn't assume a status field)

struct WorkoutSessionsScreen: View {
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    private var latestSession: WorkoutSession? { sessions.first }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    RoutinesScreen()
                } label: {
                    ActionRow(
                        title: "Start a Workout",
                        subtitle: "Pick a routine and begin logging",
                        systemImage: "play.circle.fill"
                    )
                }

                NavigationLink {
                    WorkoutSessionsHistoryScreen()
                } label: {
                    ActionRow(
                        title: "Workout History",
                        subtitle: "Review past sessions",
                        systemImage: "clock.arrow.circlepath"
                    )
                }

                if let s = latestSession {
                    NavigationLink {
                        WorkoutSessionScreen(session: s)
                    } label: {
                        ActionRow(
                            title: "Continue",
                            subtitle: s.startedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()),
                            systemImage: "bolt.fill"
                        )
                    }
                } else {
                    ActionRow(
                        title: "Continue",
                        subtitle: "No sessions yet",
                        systemImage: "bolt.fill"
                    )
                    .foregroundStyle(.secondary)
                }
            }

            Section("Recent") {
                let recent = Array(sessions.prefix(8))
                if recent.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "dumbbell",
                        description: Text("Start a routine to create your first session.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else {
                    // Safe even if WorkoutSession is not Identifiable
                    SwiftUI.ForEach(recent.indices, id: \.self) { idx in
                        let s = recent[idx]
                        NavigationLink {
                            WorkoutSessionScreen(session: s)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
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
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Local UI helper

private struct ActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.thinMaterial)
                    .frame(width: 36, height: 36)

                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

//            Image(systemName: "chevron.right")
//                .font(.caption.weight(.semibold))
//                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
