import SwiftUI

struct WorkoutSessionsScreen: View {
    var body: some View {
        List {
            Section {
                ActionRow(
                    title: "Start a Workout",
                    subtitle: "Begin a new session",
                    systemImage: "play.circle.fill"
                )

                ActionRow(
                    title: "Workout History",
                    subtitle: "Review past sessions",
                    systemImage: "clock.arrow.circlepath"
                )

                ActionRow(
                    title: "Active Session",
                    subtitle: "Continue where you left off",
                    systemImage: "bolt.fill"
                )
            }

            Section("Notes") {
                Text("Wire these actions to your real flows (session starter, history list, continue). The Home tile routing is already set.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Workouts")
    }
}

struct ActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
