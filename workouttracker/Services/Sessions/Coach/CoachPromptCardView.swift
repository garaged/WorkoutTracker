import SwiftUI

struct CoachPromptCardView: View {
    let title: String
    let message: String
    let suggestedRestSeconds: Int

    let weightActionTitle: String?
    let repsActionTitle: String?

    let onApplyWeight: (() -> Void)?
    let onApplyReps: (() -> Void)?
    let onStartRest: (() -> Void)?
    let onDismiss: () -> Void

    private let cornerRadius: CGFloat = 14

    private var hasMessage: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasPrimaryActions: Bool {
        (weightActionTitle != nil && onApplyWeight != nil) ||
        (repsActionTitle != nil && onApplyReps != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if hasPrimaryActions || onStartRest != nil {
                actionBand
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.30), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
            }
            .labelStyle(.titleAndIcon)

            if hasMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss coach suggestion")
        }
    }

    @ViewBuilder
    private var actionBand: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                primaryActions
                Spacer(minLength: 8)
                restChip
            }

            VStack(alignment: .leading, spacing: 8) {
                if hasPrimaryActions {
                    HStack(spacing: 8) {
                        primaryActions
                    }
                }

                HStack {
                    Spacer()
                    restChip
                }
            }
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        if let weightActionTitle, let onApplyWeight {
            suggestionChip(
                title: weightActionTitle,
                prominent: true,
                action: onApplyWeight
            )
        }

        if let repsActionTitle, let onApplyReps {
            suggestionChip(
                title: repsActionTitle,
                prominent: false,
                action: onApplyReps
            )
        }
    }

    @ViewBuilder
    private var restChip: some View {
        if let onStartRest {
            Button(action: onStartRest) {
                Label("\(suggestedRestSeconds)s", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func suggestionChip(
        title: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 34)
                .background(
                    prominent ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08),
                    in: Capsule()
                )
                .foregroundStyle(prominent ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
