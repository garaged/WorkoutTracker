import SwiftUI

struct ConsistencyCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ProgressDashboardViewModel.ConsistencyCardModel

    private var summary: ChartAccessibilitySummary {
        ChartAccessibilitySummaryBuilder.consistencyCard(model)
    }

    private var stacksHeader: Bool {
        AdaptiveLayoutMetrics.shouldStackProgressCardHeader(dynamicTypeSize: dynamicTypeSize)
    }

    private var statsColumns: [GridItem] {
        let count = AdaptiveLayoutMetrics.shouldUseSingleColumnProgressStats(dynamicTypeSize: dynamicTypeSize) ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            AccessibleChartSummaryView(
                summary: summary,
                identifier: "Progress.Dashboard.ConsistencySummary"
            )

            LazyVGrid(columns: statsColumns, spacing: 12) {
                statBlock(title: String(localized: "progress.dashboard.consistency.stat.active_weeks"), value: model.activeWeeksText)
                statBlock(title: String(localized: "progress.dashboard.consistency.stat.average"), value: model.averageText)
                if let completionText = model.completionText {
                    statBlock(title: String(localized: "progress.dashboard.consistency.stat.completion"), value: completionText)
                }
            }

            if let emptyMessage = model.emptyMessage {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .accessibilityCardSummary(
            label: String(localized: "progress.dashboard.consistency.title"),
            value: summary.accessibilityValue,
            identifier: "Progress.Dashboard.ConsistencyCard"
        )
    }

    @ViewBuilder
    private var header: some View {
        if stacksHeader {
            VStack(alignment: .leading, spacing: 10) {
                headerText
                availabilityPill.accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: headerAccessibilityLabel))
        } else {
            HStack(alignment: .top, spacing: 12) {
                headerText
                Spacer(minLength: 8)
                availabilityPill.accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: headerAccessibilityLabel))
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("progress.dashboard.consistency.title", systemImage: "calendar.badge.clock")
                .font(.headline)
            Text(model.headline)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
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

    private var cardBackground: some ShapeStyle {
        Color(.secondarySystemGroupedBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.quaternary)
    }

    private var headerAccessibilityLabel: String {
        [
            String(localized: "progress.dashboard.consistency.title"),
            model.headline,
            availabilityLabel(for: model.availability)
        ].joined(separator: ". ")
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
