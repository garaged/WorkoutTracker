import SwiftUI

struct StrengthProgressCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ProgressDashboardViewModel.StrengthCardModel
    let onSelectExercise: (UUID) -> Void

    private var summary: ChartAccessibilitySummary {
        ChartAccessibilitySummaryBuilder.strengthCard(model)
    }

    private var stacksHeader: Bool {
        AdaptiveLayoutMetrics.shouldStackProgressCardHeader(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            AccessibleChartSummaryView(
                summary: summary,
                identifier: "Progress.Dashboard.StrengthSummary"
            )

            if let emptyMessage = model.emptyMessage {
                lowDataCallout(
                    title: String(localized: "progress.dashboard.strength.low_data_title"),
                    message: emptyMessage
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(model.exercises) { exercise in
                        Button {
                            onSelectExercise(exercise.exerciseID)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(exercise.exerciseName)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)

                                        badge(exercise.badgeText, availability: exercise.availability)
                                    }

                                    Text(exercise.detailText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 10)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 4)
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
                        .accessibilityLabel(Text(verbatim: exerciseAccessibilityLabel(for: exercise)))
                        .accessibilityHint(Text("progress.dashboard.volume.open_exercise_detail"))
                        .accessibilityIdentifier("Progress.Dashboard.StrengthExerciseButton.\(exercise.exerciseID.uuidString)")
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .accessibilityCardSummary(
            label: String(localized: "progress.dashboard.strength.title"),
            value: summary.accessibilityValue,
            hint: summary.accessibilityHint,
            identifier: "Progress.Dashboard.StrengthCard"
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
            Label("progress.dashboard.strength.title", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
            Text(model.headline)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var availabilityPill: some View {
        Text(verbatim: availabilityLabel(for: model.availability))
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(for: model.availability))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color(for: model.availability).opacity(0.12), in: Capsule())
    }

    private func badge(_ text: String, availability: ProgressDataAvailability) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color(for: availability))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color(for: availability).opacity(0.12), in: Capsule())
            .accessibilityHidden(true)
    }

    private func lowDataCallout(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private var cardBackground: some ShapeStyle {
        Color(.secondarySystemGroupedBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.quaternary)
    }

    private var headerAccessibilityLabel: String {
        [
            String(localized: "progress.dashboard.strength.title"),
            model.headline,
            availabilityLabel(for: model.availability)
        ].joined(separator: ". ")
    }

    private func exerciseAccessibilityLabel(for exercise: ProgressDashboardViewModel.StrengthCardModel.ExerciseHighlight) -> String {
        [exercise.exerciseName, exercise.badgeText, exercise.detailText].joined(separator: ". ")
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
