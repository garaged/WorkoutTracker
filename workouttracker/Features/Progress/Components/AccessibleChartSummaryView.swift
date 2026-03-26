import SwiftUI

struct AccessibleChartSummaryView: View {
    let summary: ChartAccessibilitySummary
    var identifier: String? = nil

    var body: some View {
        let summaryContent = VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if summary.isLowData {
                    Image(systemName: "waveform.path.ecg.text.page")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                Text(summary.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .applyIfLet(identifier) { view, identifier in
                        view.accessibilityIdentifier(identifier)
                    }
            }

            if let detail = summary.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        summaryContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
            .overlay(alignment: .topLeading) {
                if let identifier {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier(identifier)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(summary.accessibilityLabel))
            .accessibilityValue(Text(summary.accessibilityValue ?? summary.headline))
            .applyIfLet(summary.accessibilityHint) { view, hint in
                view.accessibilityHint(Text(hint))
            }
            .applyIfLet(identifier) { view, identifier in
                view.accessibilityIdentifier(identifier)
            }
    }
}
