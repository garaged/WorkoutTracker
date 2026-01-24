import SwiftUI

/// A small, local undo toast (session-scoped).
/// Why here: this is UI feedback tied to the logging experience, not a global app banner.
struct UndoToastView: View {
    let message: String
    var onUndo: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            Button("Undo") { onUndo() }
                .font(.subheadline.weight(.semibold))

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss undo")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
        )
        .shadow(radius: 8, y: 3)
    }
}
