import SwiftUI
import SwiftData

struct RoutineItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var item: WorkoutRoutineItem
    @State private var editingNotes: String = ""

    init(item: WorkoutRoutineItem) {
        self.item = item
    }

    private var sortedSets: [WorkoutSetPlan] {
        item.setPlans.sorted { $0.order < $1.order }
    }

    var body: some View {
        Form {
            Section("Exercise") {
                Text(item.exercise?.name ?? "Exercise")
                    .font(.headline)

                TextField("Notes", text: $editingNotes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Set plan") {
                if sortedSets.isEmpty {
                    ContentUnavailableView(
                        "No sets",
                        systemImage: "square.stack.3d.up",
                        description: Text("Add at least 1 set.")
                    )
                }

                ForEach(sortedSets) { set in
                    SetPlanRow(set: set)
                }
                .onDelete(perform: deleteSets)
                .onMove(perform: moveSets)

                Button {
                    addSet()
                } label: {
                    Label("Add set", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Edit Sets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear {
            editingNotes = item.notes ?? ""
        }
    }

    private func save() {
        item.notes = editingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingNotes
        normalizeSetOrder()
        try? modelContext.save()
        dismiss()
    }

    private func addSet() {
        let next = (sortedSets.last?.order ?? -1) + 1
        let sp = WorkoutSetPlan(order: next, targetReps: 10, targetWeight: nil, restSeconds: 90, routineItem: item)
        item.setPlans.append(sp)
        modelContext.insert(sp)
        try? modelContext.save()
    }

    private func deleteSets(at offsets: IndexSet) {
        let sets = sortedSets
        for i in offsets {
            modelContext.delete(sets[i])
        }
        try? modelContext.save()
        normalizeSetOrder()
    }

    private func moveSets(from source: IndexSet, to destination: Int) {
        var sets = sortedSets
        sets.move(fromOffsets: source, toOffset: destination)
        for (idx, s) in sets.enumerated() { s.order = idx }
        try? modelContext.save()
    }

    private func normalizeSetOrder() {
        let sets = sortedSets
        for (idx, s) in sets.enumerated() { s.order = idx }
    }
}

private struct SetPlanRow: View {
    @Bindable var set: WorkoutSetPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set \(set.order + 1)")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                LabeledField("Reps", text: intBinding(get: { set.targetReps }, set: { set.targetReps = $0 }), keyboard: .numberPad)

                LabeledField("Weight", text: doubleBinding(get: { set.targetWeight }, set: { set.targetWeight = $0 }), keyboard: .decimalPad)

                Picker("Unit", selection: Binding(
                    get: { set.weightUnit },
                    set: { set.weightUnit = $0 }
                )) {
                    ForEach(WeightUnit.allCases, id: \.self) { u in
                        Text(u == .kg ? "kg" : "lb").tag(u)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 12) {
                LabeledField("RPE", text: doubleBinding(get: { set.targetRPE }, set: { set.targetRPE = $0 }), keyboard: .decimalPad)
                LabeledField("Rest (s)", text: intBinding(get: { set.restSeconds }, set: { set.restSeconds = $0 }), keyboard: .numberPad)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Small field helpers (optional <-> String)
    private func intBinding(get: @escaping () -> Int?, set: @escaping (Int?) -> Void) -> Binding<String> {
        Binding<String>(
            get: { get().map(String.init) ?? "" },
            set: { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                set(trimmed.isEmpty ? nil : Int(trimmed))
            }
        )
    }

    private func doubleBinding(get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> Binding<String> {
        Binding<String>(
            get: {
                guard let v = get() else { return "" }
                return String(format: "%.2f", v).replacingOccurrences(of: ".00", with: "")
            },
            set: { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ",", with: ".")
                set(trimmed.isEmpty ? nil : Double(trimmed))
            }
        )
    }
}

private struct LabeledField: View {
    let title: String
    @Binding var text: String
    let keyboard: UIKeyboardType

    init(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) {
        self.title = title
        self._text = text
        self.keyboard = keyboard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
        }
    }
}
