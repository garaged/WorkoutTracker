import SwiftUI
import SwiftData

struct ExerciseEditorSheet: View {
    enum Mode {
        case create
        case edit(Exercise)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let mode: Mode

    @State private var name: String = ""
    @State private var modality: ExerciseModality = .strength
    @State private var instructions: String = ""
    @State private var notes: String = ""

    init(mode: Mode) {
        self.mode = mode
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)

                Picker("Modality", selection: $modality) {
                    ForEach(ExerciseModality.allCases, id: \.self) { m in
                        Text(m.rawValue.capitalized).tag(m)
                    }
                }
            }

            Section("Instructions") {
                TextEditor(text: $instructions)
                    .frame(minHeight: 120)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 90)
            }
        }
        .navigationTitle(modeTitle)
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
        .onAppear { loadIfEditing() }
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "New Exercise"
        case .edit: return "Edit Exercise"
        }
    }

    private func loadIfEditing() {
        guard case let .edit(ex) = mode else { return }
        name = ex.name
        modality = ex.modality
        instructions = ex.instructions ?? ""
        notes = ex.notes ?? ""
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        switch mode {
        case .create:
            let ex = Exercise(
                name: clean,
                modality: modality,
                instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            )
            modelContext.insert(ex)

        case .edit(let ex):
            ex.name = clean
            ex.modality = modality
            ex.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions
            ex.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            ex.updatedAt = Date()
        }

        try? modelContext.save()
        dismiss()
    }
}
