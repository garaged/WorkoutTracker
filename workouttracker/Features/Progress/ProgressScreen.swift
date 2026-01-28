import SwiftUI

struct ProgressScreen: View {
    var body: some View {
        List {
            Section {
                ActionRow(
                    title: "Weekly Summary",
                    subtitle: "Workouts, sets, volume",
                    systemImage: "chart.bar.fill"
                )

                ActionRow(
                    title: "Streaks",
                    subtitle: "Current and longest streak",
                    systemImage: "flame.fill"
                )
            }

            Section("Notes") {
                Text("This is the progress hub. Hook it to your existing summary UI when ready.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Progress")
    }
}
