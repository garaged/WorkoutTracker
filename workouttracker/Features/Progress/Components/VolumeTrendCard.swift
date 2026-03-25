import SwiftUI

struct VolumeTrendCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ProgressDashboardViewModel.VolumeCardModel
    var drillDownExerciseID: UUID? = nil
    var drillDownExerciseName: String? = nil
    var onOpenExercise: ((UUID) -> Void)? = nil

    private var summary: ChartAccessibilitySummary {
        ChartAccessibilitySummaryBuilder.volumeCard(model)
    }

    private var columns: [GridItem] {
        let singleColumn = AdaptiveLayoutMetrics.shouldUseSingleColumnProgressStats(dynamicTypeSize: dynamicTypeSize)
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: singleColumn ? 1 : 2)
    }

    private var stacksHeader: Bool {
        AdaptiveLayoutMetrics.shouldStackProgressCardHeader(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            AccessibleChartSummaryView(
                summary: summary,
                identifier: "Progress.Dashboard.VolumeSummary"
            )

            if let emptyMessage = model.emptyMessage {
                lowDataCallout(message: emptyMessage)
            }

            if !model.stats.isEmpty {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(model.stats) { stat in
                        statTile(stat)
                    }
                }
            }

            if let drillDownExerciseID,
               let drillDownExerciseName,
               let onOpenExercise {
                Button {
                    onOpenExercise(drillDownExerciseID)
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("progress.dashboard.volume.open_exercise_detail")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(drillDownExerciseName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: volumeDrillDownAccessibilityLabel(exerciseName: drillDownExerciseName)))
                .accessibilityHint(Text("progress.dashboard.volume.open_exercise_detail"))
                .accessibilityIdentifier("Progress.Dashboard.Volume.OpenExercise")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .accessibilityCardSummary(
            label: String(localized: "progress.dashboard.volume.title"),
            value: summary.accessibilityValue,
            hint: summary.accessibilityHint,
            identifier: "Progress.Dashboard.VolumeCard"
        )
    }

    @ViewBuilder
    private var header: some View {
        if stacksHeader {
            VStack(alignment: .leading, spacing: 10) {
                headerText
                availabilityPill
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: headerAccessibilityLabel))
        } else {
            HStack(alignment: .top, spacing: 12) {
                headerText
                Spacer(minLength: 8)
                availabilityPill
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: headerAccessibilityLabel))
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("progress.dashboard.volume.title", systemImage: "chart.bar.fill")
                .font(.headline)
            Text(model.headline)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.primaryValue)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statTile(_ stat: ProgressDashboardViewModel.Stat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(stat.value)
                .font(.headline)
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

    private var availabilityPill: some View {
        Text(verbatim: availabilityLabel(for: model.availability))
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(for: model.availability))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color(for: model.availability).opacity(0.12), in: Capsule())
    }

    private func lowDataCallout(message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
            .accessibilityElement(children: .combine)
    }

    private var cardBackground: some ShapeStyle {
        Color(.secondarySystemGroupedBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.quaternary)
    }

    private var headerAccessibilityLabel: String {
        [
            String(localized: "progress.dashboard.volume.title"),
            model.headline,
            model.primaryValue,
            availabilityLabel(for: model.availability)
        ].joined(separator: ". ")
    }

    private func volumeDrillDownAccessibilityLabel(exerciseName: String) -> String {
        [String(localized: "progress.dashboard.volume.open_exercise_detail"), exerciseName].joined(separator: ": ")
    }

    private func availabilityLabel(for availability: ProgressDataAvailability) -> String {
        switch availability {
        case .full: return NSLocalizedString("progress.availability.ready", comment: "")
        case .partial: return NSLocalizedString("progress.availability.low_data", comment: "")
        case .insufficient: return NSLocalizedString("progress.availability.unavailable", comment: "")
        }
    }

    private func color(for availability: ProgressDataAvailability) -> Color {
        switch availability {
        case .full: return .secondary
        case .partial: return .orange
        case .insufficient: return .red
        }
    }
}
