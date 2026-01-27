import SwiftUI

struct ExercisePRSummaryView: View {
    let records: PersonalRecordsService.PersonalRecords

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)

            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    tile(title: "Top Weight", value: records.bestWeight.map { formatWeight($0.value) } ?? "—",
                         subtitle: records.bestWeight.map { formatDate($0.date) })
                    tile(title: "Top Reps", value: records.bestReps.map { "\($0.value)" } ?? "—",
                         subtitle: records.bestReps.map { formatDate($0.date) })
                }
                GridRow {
                    tile(title: "Best Set Volume", value: records.bestSetVolume.map { formatVolume($0.value) } ?? "—",
                         subtitle: records.bestSetVolume.map { formatDate($0.date) })
                    tile(title: "Best Session Volume", value: records.bestSessionVolume.map { formatVolume($0.value) } ?? "—",
                         subtitle: records.bestSessionVolume.map { formatDate($0.date) })
                }
                GridRow {
                    tile(title: "Best Est. 1RM", value: records.bestEstimated1RM.map { formatWeight($0.value) } ?? "—",
                         subtitle: records.bestEstimated1RM.map { formatDate($0.date) })
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tile(title: String, value: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func formatDate(_ d: Date) -> String {
        d.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func formatWeight(_ w: Double) -> String {
        // If you store units, swap this to use them (kg/lb).
        w.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func formatVolume(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0)))
    }
}
