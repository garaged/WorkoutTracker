import SwiftUI
import SwiftData

struct ExercisePickerSheet: View {
    private enum PickerScope: String, CaseIterable, Identifiable {
        case all
        case warmUp
        case coolDown

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .warmUp: return "Warm-up"
            case .coolDown: return "Cool-down"
            }
        }

        var role: ExerciseRoutineRole? {
            switch self {
            case .all: return nil
            case .warmUp: return .warmUp
            case .coolDown: return .coolDown
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Exercise.name, order: .forward)])
    private var exercises: [Exercise]

    let title: String
    let preferredRole: ExerciseRoutineRole?
    let onPick: (Exercise?) -> Void

    @State private var showCreate = false
    @State private var searchText = ""
    @State private var selectedScope: PickerScope

    init(
        title: String = "Pick Exercise",
        preferredRole: ExerciseRoutineRole? = nil,
        onPick: @escaping (Exercise?) -> Void
    ) {
        self.title = title
        self.preferredRole = preferredRole
        self.onPick = onPick
        switch preferredRole {
        case .warmUp:
            _selectedScope = State(initialValue: .warmUp)
        case .coolDown:
            _selectedScope = State(initialValue: .coolDown)
        case nil:
            _selectedScope = State(initialValue: .all)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleExercises.isEmpty {
                    ContentUnavailableView(
                        "No exercises",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text(emptyStateMessage)
                    )
                } else {
                    List {
                        if let role = selectedScope.role, !suggestedExercises.isEmpty {
                            Section("Suggested for \(role.displayName)") {
                                ForEach(suggestedExercises) { ex in
                                    pickButton(for: ex)
                                }
                            }
                        }

                        Section(selectedScope == .all ? "Exercises" : "All exercises") {
                            ForEach(remainingExercises) { ex in
                                pickButton(for: ex)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .safeAreaInset(edge: .top) {
                Picker("Exercise scope", selection: $selectedScope) {
                    ForEach(PickerScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                NavigationStack {
                    ExerciseQuickCreateScreen { created in
                        onPick(created)
                        showCreate = false
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredBaseExercises: [Exercise] {
        let query = searchQuery
        return exercises
            .filter { !$0.isArchived }
            .filter { ex in
                guard !query.isEmpty else { return true }
                return ex.name.localizedCaseInsensitiveContains(query)
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var visibleExercises: [Exercise] {
        filteredBaseExercises
    }

    private var suggestedExercises: [Exercise] {
        guard let role = selectedScope.role else { return [] }
        return filteredBaseExercises.filter { $0.supportsRoutineRole(role) }
    }

    private var remainingExercises: [Exercise] {
        let suggestedIDs = Set(suggestedExercises.map(\.id))
        return filteredBaseExercises.filter { !suggestedIDs.contains($0.id) }
    }

    private var emptyStateMessage: String {
        switch selectedScope {
        case .all:
            return "Create an exercise to add it to routines."
        case .warmUp:
            return "No warm-up suggestions matched your search. Switch to All to see the full library or create a new exercise."
        case .coolDown:
            return "No cool-down suggestions matched your search. Switch to All to see the full library or create a new exercise."
        }
    }

    @ViewBuilder
    private func pickButton(for ex: Exercise) -> some View {
        Button {
            onPick(ex)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(ex.name)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    pill(ex.modality.rawValue.capitalized)

                    ForEach(Array(ex.routineRoles).sorted(by: { $0.rawValue < $1.rawValue })) { role in
                        pill(role.displayName)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }


}
