import SwiftUI

/// Mini action bar used inside a set row (copy / +1 set / delete).
/// Why here: reusable component so `WorkoutSetEditorRow` stays focused on editing UI.
struct SetRowActionsBar: View {
    let isReadOnly: Bool

    var onCopy: (() -> Void)?
    var onAdd: (() -> Void)?
    var onDelete: (() -> Void)?

    /// Optional prefix to make UI test selectors unambiguous when multiple rows exist.
    /// Example: "WorkoutSetEditorRow.<setUUID>.Actions"
    var idPrefix: String = "SetRowActionsBar"

    var body: some View {
        HStack(spacing: 14) {
            Button {
                onCopy?()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .accessibilityLabel("Copy set")
            .accessibilityIdentifier("\(idPrefix).CopyButton")

            Button {
                onAdd?()
            } label: {
                Image(systemName: "plus.circle")
            }
            .accessibilityLabel("Add set")
            .accessibilityIdentifier("\(idPrefix).AddButton")

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete set")
            .accessibilityIdentifier("\(idPrefix).DeleteButton")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .disabled(isReadOnly)
    }
}
