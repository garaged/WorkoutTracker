import SwiftUI
import SwiftData

struct ExerciseEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var exercise: Exercise? = nil

    @State private var name: String = ""
    @State private var modality: ExerciseModality = .strength
    @State private var instructions: String = ""
    @State private var notes: String = ""
    @State private var equipmentText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)

                    Picker("Modality", selection: $modality) {
                        ForEach(ExerciseModality.allCases, id: \.self) { m in
                            Text(label(m)).tag(m)
                        }
                    }

                    TextField("Equipment (comma separated)", text: $equipmentText)
                        .textInputAutocapitalization(.never)

                    Text("Example: dumbbell, bench, barbell")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Instructions") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 120)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }

                if let exercise {
                    Section {
                        Toggle("Archived", isOn: Binding(
                            get: { exercise.isArchived },
                            set: { newValue in
                                exercise.isArchived = newValue
                                exercise.updatedAt = Date()
                                try? modelContext.save()
                            }
                        ))
                    }
                }
            }
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
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
            .onAppear { load() }
        }
    }

    private func load() {
        guard let e = exercise else { return }
        name = e.name
        modality = e.modality
        instructions = e.instructions ?? ""
        notes = e.notes ?? ""
        equipmentText = e.equipmentTagsRaw
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        if let e = exercise {
            e.name = cleanName
            e.modality = modality
            e.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions
            e.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            e.equipmentTagsRaw = equipmentText
            e.updatedAt = Date()
        } else {
            let e = Exercise(
                name: cleanName,
                modality: modality,
                instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                equipmentTagsRaw: equipmentText
            )
            modelContext.insert(e)
        }

        try? modelContext.save()
        dismiss()
    }

    private func label(_ m: ExerciseModality) -> String {
        switch m {
        case .strength: return "Strength"
        case .timed: return "Timed"
        case .cardio: return "Cardio"
        case .mobility: return "Mobility"
        }
    }
}
