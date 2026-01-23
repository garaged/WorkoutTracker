import SwiftUI
import SwiftData

struct ExerciseQuickCreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""

    let onCreated: (Exercise) -> Void

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)
            }
        }
        .navigationTitle("New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
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
