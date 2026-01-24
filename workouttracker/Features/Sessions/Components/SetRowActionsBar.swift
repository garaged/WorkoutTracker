import SwiftUI

/// Mini action bar used inside a set row (copy / +1 set / delete).
/// Why here: reusable component so `WorkoutSetEditorRow` stays focused on editing UI.
struct SetRowActionsBar: View {
    let isReadOnly: Bool

    var onCopy: (() -> Void)?
    var onAdd: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Button {
                onCopy?()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .accessibilityLabel("Copy set")

            Button {
                onAdd?()
            } label: {
                Image(systemName: "plus.circle")
            }
            .accessibilityLabel("Add set")

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete set")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .disabled(isReadOnly)
    }
}
