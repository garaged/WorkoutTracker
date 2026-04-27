import SwiftUI

struct MissedSessionCard: View {
    let missedCount: Int
    let currentWeekIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "Missed sessions", defaultValue: "Missed sessions"), systemImage: "clock.badge.exclamationmark")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(
                String(
                    format: String(localized: "Week %lld has %lld missed sessions.", defaultValue: "Week %lld has %lld missed sessions."),
                    Int64(currentWeekIndex),
                    Int64(missedCount)
                )
            )
            .font(.subheadline.weight(.semibold))

            Text(String(localized: "Complete the missed day before advancing.", defaultValue: "Complete the missed day before advancing."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }
}
