import SwiftUI

struct VolumeTrendCard: View {
    let model: ProgressDashboardViewModel.VolumeCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(model.supportingText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Volume", systemImage: "chart.bar.fill")
                    .font(.headline)
                Text(model.headline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(model.primaryValue)
                    .font(.title2.weight(.semibold))
            }

            Spacer(minLength: 8)

            availabilityPill
        }
    }

    private func statTile(_ stat: ProgressDashboardViewModel.Stat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(stat.value)
                .font(.headline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private var availabilityPill: some View {
        Text(label(for: model.availability))
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
    }

    private var cardBackground: some ShapeStyle {
        Color(.secondarySystemGroupedBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.quaternary)
    }

    private func label(for availability: ProgressDataAvailability) -> String {
        switch availability {
        case .full: return "Ready"
        case .partial: return "Low data"
        case .insufficient: return "Unavailable"
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
