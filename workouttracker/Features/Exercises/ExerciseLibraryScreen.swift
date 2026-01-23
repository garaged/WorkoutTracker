import SwiftUI
import SwiftData

struct ExerciseLibraryScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Exercise.name, order: .forward)])
    private var allExercises: [Exercise]

    @State private var searchText: String = ""
    @State private var showArchived: Bool = false
    @State private var modalityFilter: ExerciseModality? = nil

    @State private var showNewExerciseSheet = false
    @State private var editingExercise: Exercise? = nil

    private var filtered: [Exercise] {
        allExercises
            .filter { showArchived ? true : !$0.isArchived }
            .filter {
                guard let modalityFilter else { return true }
                return $0.modality == modalityFilter
            }
            .filter {
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return true }
                return $0.name.localizedCaseInsensitiveContains(q)
            }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No exercises",
                    systemImage: "dumbbell",
                    description: Text("Create your first exercise to start building routines and tracking history.")
                )
            } else {
                ForEach(filtered) { ex in
                    NavigationLink {
                        ExerciseDetailScreen(exercise: ex)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.name).font(.headline)
                                Text(ex.modality.rawValue.capitalized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if ex.isArchived {
                                Text("Archived")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial, in: Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .contextMenu {
                        Button {
                            editingExercise = ex
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: ex.isArchived ? .cancel : .destructive) {
                            ex.isArchived.toggle()
                            ex.updatedAt = Date()
                            try? modelContext.save()
                        } label: {
                            Label(ex.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewExerciseSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .top) {
            filtersBar
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showNewExerciseSheet) {
            NavigationStack {
                ExerciseEditorSheet(mode: .create)
            }
        }
        .sheet(item: $editingExercise) { ex in
            NavigationStack {
                ExerciseEditorSheet(mode: .edit(ex))
            }
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("All") { modalityFilter = nil }
                Divider()
                ForEach(ExerciseModality.allCases, id: \.self) { m in
                    Button(m.rawValue.capitalized) { modalityFilter = m }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(modalityFilter?.rawValue.capitalized ?? "All modalities")
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            Toggle("Archived", isOn: $showArchived)
                .toggleStyle(.switch)
                .labelsHidden()

            Spacer()
        }
    }
}
