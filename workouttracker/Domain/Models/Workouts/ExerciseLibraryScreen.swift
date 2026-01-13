import SwiftUI
import SwiftData

struct ExerciseLibraryScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Exercise.name, order: .forward)])
    private var allExercises: [Exercise]

    @State private var searchText: String = ""
    @State private var selectedModality: ExerciseModality? = nil
    @State private var selectedEquipment: String? = nil
    @State private var showArchived: Bool = false

    @State private var showNewExercise = false
    @State private var editingExercise: Exercise? = nil

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No exercises",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Add an exercise, or clear filters.")
                )
            } else {
                ForEach(filtered) { ex in
                    NavigationLink {
                        ExerciseDetailScreen(exercise: ex)
                    } label: {
                        ExerciseRow(exercise: ex)
                    }
                    .contextMenu {
                        Button {
                            editingExercise = ex
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            ex.isArchived = true
                            ex.updatedAt = Date()
                            try? modelContext.save()
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Modality", selection: Binding(
                        get: { selectedModality },
                        set: { selectedModality = $0 }
                    )) {
                        Text("Any").tag(ExerciseModality?.none)
                        ForEach(ExerciseModality.allCases, id: \.self) { m in
                            Text(label(m)).tag(Optional(m))
                        }
                    }

                    Divider()

                    Picker("Equipment", selection: Binding(
                        get: { selectedEquipment },
                        set: { selectedEquipment = $0 }
                    )) {
                        Text("Any").tag(String?.none)
                        ForEach(allEquipmentTags, id: \.self) { tag in
                            Text(tag).tag(Optional(tag))
                        }
                    }

                    Divider()

                    Toggle("Show archived", isOn: $showArchived)

                    if selectedModality != nil || selectedEquipment != nil || !searchText.isEmpty {
                        Divider()
                        Button("Clear filters") {
                            selectedModality = nil
                            selectedEquipment = nil
                            searchText = ""
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }

                Button {
                    showNewExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewExercise) {
            ExerciseEditorSheet()
        }
        .sheet(item: $editingExercise) { ex in
            ExerciseEditorSheet(exercise: ex)
        }
    }

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allExercises.filter { ex in
            if !showArchived, ex.isArchived { return false }

            if let selectedModality, ex.modality != selectedModality { return false }

            if let selectedEquipment {
                if !ex.equipmentTags.contains(selectedEquipment.lowercased()) { return false }
            }

            if q.isEmpty { return true }
            return ex.name.lowercased().contains(q)
                || (ex.instructions ?? "").lowercased().contains(q)
                || (ex.notes ?? "").lowercased().contains(q)
        }
    }

    private var allEquipmentTags: [String] {
        let tags = allExercises.flatMap { $0.equipmentTags }
        let uniq = Array(Set(tags))
        return uniq.sorted()
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

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                Spacer()
                Text(modalityLabel(exercise.modality))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }

            if !exercise.equipmentTags.isEmpty {
                Text(exercise.equipmentTags.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func modalityLabel(_ m: ExerciseModality) -> String {
        switch m {
        case .strength: return "Strength"
        case .timed: return "Timed"
        case .cardio: return "Cardio"
        case .mobility: return "Mobility"
        }
    }
}
