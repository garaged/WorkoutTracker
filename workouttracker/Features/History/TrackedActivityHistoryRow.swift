import SwiftUI

struct TrackedActivityHistoryRow: View {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(badgeColor)
            }

            HStack(spacing: 8) {
                if let startedAt = session.startedAt {
                    Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if session.healthKitExportState == .failed {
                    Label(String(localized: "activities.history.export_failed", defaultValue: "Apple Health save failed"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if session.healthKitExportState == .pending {
                    Label(String(localized: "activities.history.export_pending", defaultValue: "Apple Health save pending"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let metrics = summaryBuilder.metrics(for: session)
                .filter { $0.kind != .state }
                .prefix(3)

            if !metrics.isEmpty {
                HStack(spacing: 12) {
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
            } else {
                Text(String(localized: "activities.history.low_data", defaultValue: "No additional metrics were recorded for this activity."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("TrackedActivity.HistoryRow.\(session.id.uuidString)")
    }

    private var badgeColor: Color {
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
