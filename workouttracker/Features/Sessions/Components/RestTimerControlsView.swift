import SwiftUI

struct RestTimerControlsView: View {
    let options: [Int]
    let isEnabled: Bool
    let onExtend: (Int) -> Void

    init(
        options: [Int] = [15, 30, 60],
        isEnabled: Bool,
        onExtend: @escaping (Int) -> Void
    ) {
        self.options = options
        self.isEnabled = isEnabled
        self.onExtend = onExtend
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { seconds in
                Button {
                    onExtend(seconds)
                } label: {
                    Text(AppFormatting.localizedFormat("+%@", AppFormatting.shortDuration(seconds: seconds)))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .accessibilityLabel(Text(verbatim: accessibilityLabel(for: seconds)))
                .accessibilityValue(Text(verbatim: AppFormatting.shortDuration(seconds: seconds)))
                .accessibilityIdentifier("RestTimerControlsView.Extend\(seconds)Button")
            }
        }
        .accessibilityIdentifier("RestTimerControlsView")
    }

    private func accessibilityLabel(for seconds: Int) -> String {
        switch seconds {
        case 15: return AccessibilityLabels.Buttons.extendRest15
        case 30: return AccessibilityLabels.Buttons.extendRest30
        case 60: return AccessibilityLabels.Buttons.extendRest60
        default: return AppFormatting.shortDuration(seconds: seconds)
        }
    }
}
