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
            actionButton(
                systemName: "doc.on.doc",
                accessibilityLabel: "Copy set",
                accessibilityIdentifier: "\(idPrefix).CopyButton"
            ) {
                onAction(.copy)
            }

            actionButton(
                systemName: "plus.circle",
                accessibilityLabel: "Add set",
                accessibilityIdentifier: "\(idPrefix).AddButton"
            ) {
                onAction(.add)
            }

            actionButton(
                systemName: "trash",
                accessibilityLabel: "Delete set",
                accessibilityIdentifier: "\(idPrefix).DeleteButton",
                role: .destructive
            ) {
                onAction(.delete)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .disabled(isReadOnly)
    }

    @ViewBuilder
    private func actionButton(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
