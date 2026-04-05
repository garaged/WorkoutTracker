import SwiftUI
import SwiftData

struct ExerciseProgressDetailView: View {
    let exerciseID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel = ExerciseProgressDetailViewModel()

    private var stacksHeader: Bool {
        AdaptiveLayoutMetrics.shouldStackExerciseDetailHeader(dynamicTypeSize: dynamicTypeSize)
    }

    private var keyMetricColumns: [GridItem] {
        let count = AdaptiveLayoutMetrics.shouldStackExerciseDetailMetrics(dynamicTypeSize: dynamicTypeSize) ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .failed(let message):
                failureView(message: message)
            case .lowData(let content):
                detailContent(content, isLowData: true)
            case .content(let content):
                detailContent(content, isLowData: false)
            }
        }
        .navigationTitle(String(localized: "progress.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: exerciseID) {
            viewModel.configureIfNeeded(context: modelContext)
            viewModel.load(exerciseID: exerciseID)
        }
        .refreshable {
            viewModel.configureIfNeeded(context: modelContext)
            viewModel.refresh(exerciseID: exerciseID)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(String(localized: "progress.detail.loading"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityIdentifier("Progress.Detail.Loading")
    }

    private func failureView(message: String) -> some View {
        ContentUnavailableView(
            String(localized: "progress.detail.failure_title"),
            systemImage: "exclamationmark.triangle",
            description: Text(verbatim: message)
        )
        .accessibilityIdentifier("Progress.Detail.Failure")
    }

    private func detailContent(
        _ content: ExerciseProgressDetailViewModel.DetailContent,
        isLowData: Bool
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(content)

                if isLowData, let message = content.lowDataMessage {
                    ProgressEmptyStateView(kind: .lowData(message: message))
                        .accessibilityIdentifier("Progress.Detail.LowData")
                }

                keyMetrics(content)

                personalRecordsSection(content)
                    .accessibilityIdentifier("Progress.Detail.PersonalRecordsSection")

                weeklyVolumeSection(content)
                    .accessibilityIdentifier("Progress.Detail.VolumeSection")

                recentPerformanceSection(content)
                    .accessibilityIdentifier("Progress.Detail.RecentPerformanceSection")
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("Progress.Detail.Screen")
    }

    private func header(_ content: ExerciseProgressDetailViewModel.DetailContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.exerciseName)
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("Progress.Detail.ExerciseName")

            if stacksHeader {
                VStack(alignment: .leading, spacing: 8) {
                    availabilityPill(content.availability)

                    if let latestTopSet = content.latestTopSet {
                        Text(latestTopSet.valueText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    availabilityPill(content.availability)

                    if let latestTopSet = content.latestTopSet {
                        Text(latestTopSet.valueText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }

            Text(String(localized: "progress.detail.header_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: headerAccessibilityLabel(content)))
    }

    private func keyMetrics(_ content: ExerciseProgressDetailViewModel.DetailContent) -> some View {
        Group {
            if content.estimatedOneRepMax != nil || content.latestTopSet != nil {
                LazyVGrid(columns: keyMetricColumns, spacing: 12) {
                    if let estimated = content.estimatedOneRepMax {
                        keyMetricTile(estimated)
                            .accessibilityIdentifier("Progress.Detail.Estimated1RM")
                    }

                    if let latestTopSet = content.latestTopSet {
                        keyMetricTile(latestTopSet)
                            .accessibilityIdentifier("Progress.Detail.LatestTopSet")
                    }
                }
            }
        }
    }

    private func keyMetricTile(_ metric: ExerciseProgressDetailViewModel.KeyMetric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(metric.valueText)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(metric.subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary)
        )
        .accessibilityElement(children: .combine)
    }

    private func personalRecordsSection(_ content: ExerciseProgressDetailViewModel.DetailContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: String(localized: "progress.detail.section.personal_records"), systemImage: "rosette")

            if content.personalRecords.isEmpty {
                ProgressEmptyStateView(
                    kind: .sectionUnavailable(
                        title: String(localized: "progress.detail.empty.personal_records.title"),
                        message: String(localized: "progress.detail.empty.personal_records.message")
                    )
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(content.personalRecords) { record in
                        detailRow(title: record.title, value: record.valueText, subtitle: record.subtitleText)
                    }
                }
            }
        }
    }

    private func weeklyVolumeSection(_ content: ExerciseProgressDetailViewModel.DetailContent) -> some View {
        let summary = ChartAccessibilitySummaryBuilder.exerciseVolumeTrend(content.summary.weeklyVolumeTrend)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: String(localized: "progress.detail.section.recent_volume"), systemImage: "chart.bar.fill")

            AccessibleChartSummaryView(summary: summary, identifier: "Progress.Detail.VolumeSummary")

            if content.weeklyVolumeRows.isEmpty {
                ProgressEmptyStateView(
                    kind: .sectionUnavailable(
                        title: String(localized: "progress.detail.empty.recent_volume.title"),
                        message: String(localized: "progress.detail.empty.recent_volume.message")
                    )
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(content.weeklyVolumeRows) { row in
                        detailRow(title: row.title, value: row.valueText, subtitle: row.subtitleText)
                    }
                }
            }
        }
    }

    private func recentPerformanceSection(_ content: ExerciseProgressDetailViewModel.DetailContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: String(localized: "progress.detail.section.recent_performance"), systemImage: "figure.strengthtraining.traditional")

            if content.recentPerformanceRows.isEmpty {
                ProgressEmptyStateView(
                    kind: .sectionUnavailable(
                        title: String(localized: "progress.detail.empty.recent_performance.title"),
                        message: String(localized: "progress.detail.empty.recent_performance.message")
                    )
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(content.recentPerformanceRows) { row in
                        detailRow(title: row.title, value: row.valueText, subtitle: row.subtitleText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailRow(title: String, value: String, subtitle: String) -> some View {
        let stackValue = AdaptiveLayoutMetrics.shouldStackProgressDetailRow(dynamicTypeSize: dynamicTypeSize)
        if stackValue {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .accessibilityElement(children: .combine)
        }
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }

    private func availabilityPill(_ availability: ProgressDataAvailability) -> some View {
        Text(verbatim: availabilityText(for: availability))
            .font(.caption.weight(.semibold))
            .foregroundStyle(availabilityColor(for: availability))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(availabilityColor(for: availability).opacity(0.12), in: Capsule())
            .accessibilityHidden(true)
    }

    private func headerAccessibilityLabel(_ content: ExerciseProgressDetailViewModel.DetailContent) -> String {
        var parts = [content.exerciseName, availabilityText(for: content.availability)]
        if let latestTopSet = content.latestTopSet {
            parts.append(latestTopSet.valueText)
        }
        parts.append(String(localized: "progress.detail.header_subtitle"))
        return parts.joined(separator: ". ")
    }

    private func availabilityText(for availability: ProgressDataAvailability) -> String {
        switch availability {
        case .full:
            return String(localized: "progress.availability.ready")
        case .partial:
            return String(localized: "progress.availability.low_data")
        case .insufficient:
            return String(localized: "progress.availability.unavailable")
        }
    }

    private func availabilityColor(for availability: ProgressDataAvailability) -> Color {
        switch availability {
        case .full:
            return .secondary
        case .partial:
            return .orange
        case .insufficient:
            return .red
        }
    }
}
