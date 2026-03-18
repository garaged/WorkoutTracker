import SwiftUI

struct StrengthProgressCard: View {
    let model: ProgressDashboardViewModel.StrengthCardModel
    let onSelectExercise: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(model.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.tertiarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Progress.Dashboard.StrengthExerciseButton.\(exercise.exerciseID.uuidString)")
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Progress.Dashboard.StrengthCard")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Label("progress.dashboard.strength.title", systemImage: "figure.strengthtraining.traditional")
                    .font(.headline)
                Text(model.headline)
                    .font(.title3.weight(.semibold))
            }

            Spacer(minLength: 8)

            availabilityPill
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
    }

    private var cardBackground: some ShapeStyle {
        Color(.secondarySystemGroupedBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.quaternary)
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
