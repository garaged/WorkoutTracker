import SwiftUI

struct TrackedActivitySummaryCardModel: Equatable {
    struct RecentSession: Identifiable, Equatable {
        let id: UUID
        let title: String
        let subtitle: String
        let detail: String
        let activityKind: TrackedActivityKind
    }

    let headline: String
    let supportingText: String
    let recentSessions: [RecentSession]
    let emptyMessage: String?

    static func build(from summaries: [TrackedActivitySummary], summaryBuilder: TrackedActivitySummaryBuilder = .init()) -> TrackedActivitySummaryCardModel? {
        let completed = summaries
            .filter { $0.lifecycleState == .completed }
            .sorted { ($0.endedAt ?? $0.startedAt ?? .distantPast) > ($1.endedAt ?? $1.startedAt ?? .distantPast) }

        guard !completed.isEmpty else {
            return nil
        }

        let recent = Array(completed.prefix(3)).map { summary -> RecentSession in
            let metrics = summaryBuilder.metrics(for: summary)
                .filter { $0.kind != .state }
                .prefix(2)
                .map(\.value)
                .joined(separator: " • ")

            let date = (summary.endedAt ?? summary.startedAt ?? .now).formatted(date: .abbreviated, time: .shortened)

            return RecentSession(
                id: summary.sessionID,
                title: summary.activityKind.displayName,
                subtitle: date,
                detail: metrics.isEmpty
                    ? String(localized: "progress.activities.low_data", defaultValue: "Low-data activity")
                    : metrics,
                activityKind: summary.activityKind
            )
        }

        let totalDuration = completed.reduce(0) { $0 + $1.totals.elapsedDuration }
        let durationText = TrackedActivitySummaryBuilder.formatDuration(totalDuration)

        return TrackedActivitySummaryCardModel(
            headline: String(localized: "progress.activities.headline", defaultValue: "Tracked activity recap"),
            supportingText: String(
                localized: "progress.activities.supporting",
                defaultValue: "\(completed.count) completed tracked activities • \(durationText) total"
            ),
            recentSessions: recent,
            emptyMessage: nil
        )
    }
}

struct TrackedActivitySummaryCard: View {
    let model: TrackedActivitySummaryCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(String(localized: "progress.activities.title", defaultValue: "Tracked activities"), systemImage: "figure.walk.motion")
                        .font(.headline)
                    Text(model.headline)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("Progress.Dashboard.TrackedActivitiesHeader")

            Text(model.supportingText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let emptyMessage = model.emptyMessage {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(model.recentSessions) { session in
                        HStack(alignment: .top, spacing: 12) {
                            Label(session.title, systemImage: session.activityKind.systemImage)
                                .font(.body.weight(.semibold))
                            Spacer(minLength: 10)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .topTrailing) {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(session.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(session.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary)
        )
        .accessibilityIdentifier("Progress.Dashboard.TrackedActivitiesCard")
    }
}
