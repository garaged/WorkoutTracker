import SwiftUI
import SwiftData

struct RoutineEditorScreen: View {
    enum Mode {
        case create
        case edit(WorkoutRoutine)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let mode: Mode

    @State private var name: String
    @State private var notes: String
    @State private var isArchived: Bool

    init(mode: Mode = .create) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _notes = State(initialValue: "")
            _isArchived = State(initialValue: false)
        case .edit(let r):
            _name = State(initialValue: r.name)
            _notes = State(initialValue: r.notes ?? "")
            _isArchived = State(initialValue: r.isArchived)
        }
    }

    var body: some View {
        Form {
            Section("Routine") {
                TextField("Name", text: $name)
                Toggle("Archived", isOn: $isArchived)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 120)
            }

            Section {
                Text("Next step: add items (exercises) + reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "New Routine"
        case .edit: return "Edit Routine"
        }
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        switch mode {
        case .create:
            let r = WorkoutRoutine(name: clean,
                                 notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                                 isArchived: isArchived)
            modelContext.insert(r)

        case .edit(let r):
            r.name = clean
            r.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            r.isArchived = isArchived
            r.updatedAt = Date()
        }

        try? modelContext.save()
        dismiss()
    }
}
