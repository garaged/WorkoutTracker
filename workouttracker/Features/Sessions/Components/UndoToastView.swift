import SwiftUI

/// A small, local undo toast (session-scoped).
/// Why here: this is UI feedback tied to the logging experience, not a global app banner.
struct UndoToastView: View {
    let message: String
    var onUndo: () -> Void
    var onDismiss: () -> Void

    private let cornerRadius: CGFloat = 14

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.08), in: Circle())

            Text(message)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            Button("Undo") { onUndo() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .buttonStyle(.plain)
                .accessibilityIdentifier("UndoToastView.UndoButton")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss undo")
            .accessibilityIdentifier("UndoToastView.DismissButton")
        }
        .accessibilityIdentifier("UndoToastView.Container")
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.30), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}
