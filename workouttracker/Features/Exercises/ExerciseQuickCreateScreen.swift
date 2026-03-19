import SwiftUI
import SwiftData

struct ExerciseQuickCreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""

    let onCreated: (Exercise) -> Void

    var body: some View {
        Form {
            Section(AppFormatting.localized("Exercise")) {
                TextField(AppFormatting.localized("Name"), text: $name)
            }
        }
        .navigationTitle(AppFormatting.localized("New Exercise"))
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

        let ex = Exercise(name: clean)
        modelContext.insert(ex)
        try? modelContext.save()
        onCreated(ex)
        dismiss()
    }
}
