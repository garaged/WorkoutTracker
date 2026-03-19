import SwiftUI
import SwiftData

struct RoutineQuickCreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var notes: String = ""

    let onCreated: (WorkoutRoutine) -> Void

    var body: some View {
        Form {
            Section(AppFormatting.localized("Routine")) {
                TextField(AppFormatting.localized("Name"), text: $name)
                TextField(AppFormatting.localized("Notes"), text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle(AppFormatting.localized("New Routine"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(AppFormatting.localized("Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(AppFormatting.localized("Save")) { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let routine = WorkoutRoutine(
            name: clean,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )

        modelContext.insert(routine)
        try? modelContext.save()

        onCreated(routine)
        dismiss()
    }
}
