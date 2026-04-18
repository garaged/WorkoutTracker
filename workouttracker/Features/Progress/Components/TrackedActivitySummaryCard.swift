import SwiftUI

struct TrackedActivitySummaryCardModel: Equatable {
    struct RecentSession: Identifiable, Equatable {
        let id: UUID
        let title: String
        let subtitle: String
        let detail: String
        let activityKind: TrackedActivityKind
    }

    struct SummaryStat: Identifiable, Equatable {
        let id: String
        let title: String
        let value: String
        let isEmphasized: Bool
    }

    struct ActivityMixItem: Identifiable, Equatable {
        let id: String
        let title: String
        let count: Int
        let value: String
        let systemImage: String
        let activityKind: TrackedActivityKind
    }

    let headline: String
    let supportingText: String
    let stats: [SummaryStat]
    let activityMix: [ActivityMixItem]
    let recentSessions: [RecentSession]
    let lowDataMessage: String?
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

        let distanceCapableSessions = completed.filter { $0.activityKind.supportsDistance }
        let distanceSessions = distanceCapableSessions.compactMap(\.totals.distanceMeters).filter { $0 > 0 }
        let totalDistance = distanceSessions.reduce(0, +)
        let outdoorCount = completed.filter { $0.environment == .outdoor }.count

        let stats = makeStats(
            durationText: durationText,
            totalDistanceMeters: totalDistance > 0 ? totalDistance : nil,
            distanceSessionCount: distanceSessions.count,
            distanceCapableCount: distanceCapableSessions.count,
            outdoorCount: outdoorCount
        )

        let activityMix = makeActivityMix(from: completed)

        let supportingText: String = {
            if totalDistance > 0 {
                return String(
                    localized: "progress.activities.supporting.with_distance",
                    defaultValue: "\(completed.count) completed tracked activities • \(durationText) • \(formatDistance(totalDistance))"
                )
            }
            return String(
                localized: "progress.activities.supporting",
                defaultValue: "\(completed.count) completed tracked activities • \(durationText) total"
            )
        }()

        let lowDataMessage: String? = {
            guard !distanceCapableSessions.isEmpty else { return nil }
            if distanceSessions.isEmpty {
                return String(
                    localized: "progress.activities.low_data.distance_missing",
                    defaultValue: "Distance totals appear when walking, running, or hiking activities record distance or route data."
                )
            }
            if distanceSessions.count < distanceCapableSessions.count {
                return String(
                    localized: "progress.activities.low_data.distance_partial",
                    defaultValue: "Distance totals reflect only tracked activities that recorded distance."
                )
            }
            return nil
        }()

        let headline: String = {
            if let topMix = activityMix.first {
                return String(
                    localized: "progress.activities.headline.mixed",
                    defaultValue: "\(topMix.title) leads your recent tracked activity"
                )
            }
            return String(localized: "progress.activities.headline", defaultValue: "Tracked activity recap")
        }()

        return TrackedActivitySummaryCardModel(
            headline: headline,
            supportingText: supportingText,
            stats: stats,
            activityMix: activityMix,
            recentSessions: recent,
            lowDataMessage: lowDataMessage,
            emptyMessage: nil
        )
    }

    private static func makeStats(
        durationText: String,
        totalDistanceMeters: Double?,
        distanceSessionCount: Int,
        distanceCapableCount: Int,
        outdoorCount: Int
    ) -> [SummaryStat] {
        var stats: [SummaryStat] = [
            SummaryStat(
                id: "duration",
                title: String(localized: "progress.activities.stats.duration", defaultValue: "Total time"),
                value: durationText,
                isEmphasized: true
            )
        ]

        if let totalDistanceMeters, totalDistanceMeters > 0 {
            stats.append(
                SummaryStat(
                    id: "distance",
                    title: String(localized: "progress.activities.stats.distance", defaultValue: "Distance"),
                    value: formatDistance(totalDistanceMeters),
                    isEmphasized: true
                )
            )
        } else if distanceCapableCount > 0 {
            stats.append(
                SummaryStat(
                    id: "distance_low_data",
                    title: String(localized: "progress.activities.stats.distance", defaultValue: "Distance"),
                    value: String(localized: "progress.activities.stats.distance_low_data", defaultValue: "Low data"),
                    isEmphasized: false
                )
            )
        }

        if outdoorCount > 0 {
            stats.append(
                SummaryStat(
                    id: "outdoor_count",
                    title: String(localized: "progress.activities.stats.outdoor", defaultValue: "Outdoor"),
                    value: String(
                        localized: "progress.activities.stats.outdoor_count",
                        defaultValue: "\(outdoorCount) sessions"
                    ),
                    isEmphasized: false
                )
            )
        } else if distanceSessionCount > 0 {
            stats.append(
                SummaryStat(
                    id: "distance_sessions",
                    title: String(localized: "progress.activities.stats.distance_recorded", defaultValue: "With distance"),
                    value: String(
                        localized: "progress.activities.stats.distance_session_count",
                        defaultValue: "\(distanceSessionCount) sessions"
                    ),
                    isEmphasized: false
                )
            )
        }

        return Array(stats.prefix(3))
    }

    private static func makeActivityMix(from summaries: [TrackedActivitySummary]) -> [ActivityMixItem] {
        let counts = Dictionary(grouping: summaries, by: \.activityKind)
            .mapValues(\.count)

        return TrackedActivityKind.allCases
            .compactMap { kind -> ActivityMixItem? in
                guard let count = counts[kind], count > 0 else { return nil }
                return ActivityMixItem(
                    id: kind.rawValue,
                    title: kind.displayName,
                    count: count,
                    value: AppFormatting.integer(count),
                    systemImage: kind.systemImage,
                    activityKind: kind
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.title < rhs.title }
                return lhs.count > rhs.count
            }
            .prefix(3)
            .map { $0 }
    }

    private static func formatDistance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

struct TrackedActivitySummaryCard: View {
    let model: TrackedActivitySummaryCardModel

    private let statColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

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

            if !model.activityMix.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.activityMix) { item in
                            Label {
                                Text(
                                    String(
                                        format: String(
                                            localized: "progress.activities.mix.item",
                                            defaultValue: "%1$@ • %2$@"
                                        ),
                                        item.title,
                                        item.value
                                    )
                                )
                            } icon: {
                                Image(systemName: item.systemImage)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(activityMixTint(for: item.activityKind).opacity(0.12), in: Capsule())
                            .foregroundStyle(activityMixTint(for: item.activityKind))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .accessibilityIdentifier("Progress.Dashboard.TrackedActivitiesMix")
            }

            if !model.stats.isEmpty {
                LazyVGrid(columns: statColumns, spacing: 12) {
                    ForEach(model.stats) { stat in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stat.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(stat.value)
                                .font(stat.isEmphasized ? .headline : .subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            if let lowDataMessage = model.lowDataMessage {
                Text(lowDataMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }

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
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.18), Color.blue.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6)
                .padding(.vertical, 10)
        }
        .accessibilityIdentifier("Progress.Dashboard.TrackedActivitiesCard")
    }

    private func activityMixTint(for kind: TrackedActivityKind) -> Color {
        switch kind {
        case .walking: return .green
        case .running: return .orange
        case .hiking: return .brown
        case .yoga: return .purple
        }
    }
}
