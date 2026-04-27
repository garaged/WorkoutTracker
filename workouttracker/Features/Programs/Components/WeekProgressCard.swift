import SwiftUI

struct WeekProgressCard: View {
    let weekTitle: String
    let completion: ProgramWeekCompletion

    private var progressValue: Double {
        guard completion.requiredDays > 0 else { return 0 }
        return Double(completion.completedRequiredDays) / Double(completion.requiredDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(weekTitle)
                .font(.headline)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: progressValue)
                .tint(.orange)

            HStack(spacing: 12) {
                metricLabel(
                    title: String(localized: "Completed", defaultValue: "Completed"),
                    value: "\(completion.completedRequiredDays)"
                )
                metricLabel(
                    title: String(localized: "Remaining", defaultValue: "Remaining"),
                    value: "\(completion.remainingRequiredDays)"
                )
                metricLabel(
                    title: String(localized: "Missed", defaultValue: "Missed"),
                    value: "\(completion.missedRequiredDays)"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private var summaryText: String {
        String(
            format: String(
                localized: "Week %1$lld is %2$lld of %3$lld sessions complete.",
                defaultValue: "Week %1$lld is %2$lld of %3$lld sessions complete."
            ),
            Int64(completion.weekIndex),
            Int64(completion.completedRequiredDays),
            Int64(completion.requiredDays)
        )
    }

    private func metricLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
