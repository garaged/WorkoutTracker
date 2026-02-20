import SwiftUI

struct ProgressScreen: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    WeekProgressScreen()
                } label: {
                    ProgressHubRow(
                        title: "Weekly Summary",
                        subtitle: "Workouts, sets, volume",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }

                NavigationLink {
                    WeekProgressScreen()
                } label: {
                    ProgressHubRow(
                        title: "Streaks",
                        subtitle: "Current and longest streak",
                        systemImage: "flame.fill"
                    )
                }
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProgressHubRow: View {
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
