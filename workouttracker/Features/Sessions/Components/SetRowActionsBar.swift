import SwiftUI

/// Mini action bar used inside a set row (copy / +1 set / delete).
/// Why here: reusable component so `WorkoutSetEditorRow` stays focused on editing UI.
struct SetRowActionsBar: View {

    enum Action {
        case copy
        case add
        case delete
    }

    let isReadOnly: Bool
    let onAction: (Action) -> Void

    /// Optional prefix to make UI test selectors unambiguous when multiple rows exist.
    /// Example: "WorkoutSetEditorRow.<setUUID>.Actions"
    var idPrefix: String = "SetRowActionsBar"

    var body: some View {
        HStack(spacing: 14) {
            Button {
                onAction(.copy)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .accessibilityLabel("Copy set")
            .accessibilityIdentifier("\(idPrefix).CopyButton")

            Button {
                onAction(.add)
            } label: {
                Image(systemName: "plus.circle")
            }
            .accessibilityLabel("Add set")
            .accessibilityIdentifier("\(idPrefix).AddButton")

            Button(role: .destructive) {
                onAction(.delete)
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
