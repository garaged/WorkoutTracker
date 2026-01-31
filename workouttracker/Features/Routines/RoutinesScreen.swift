import SwiftUI
import SwiftData

@MainActor
struct RoutinesScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @State private var searchText: String = ""
    @State private var nameEditor: RoutineNameEditorState? = nil

    @State private var routineToDelete: WorkoutRoutine? = nil
    @State private var showDeleteConfirm: Bool = false

    @State private var launchedSession: WorkoutSession? = nil
    @State private var showSessionCover: Bool = false

    var body: some View {
        // ✅ Cache once: helps the type-checker + avoids recomputing repeatedly
        let items = filteredRoutines

        return List {
            listContent(items)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Routines")
        .searchable(text: $searchText, prompt: "Search routines")
        .toolbar { topToolbar }
        .sheet(item: $nameEditor, content: nameEditorSheet)
        .confirmationDialog(
            "Delete routine?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteConfirmed() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .fullScreenCover(isPresented: $showSessionCover, content: sessionCover)
    }

    // MARK: - List content

    @ViewBuilder
    private func listContent(_ items: [WorkoutRoutine]) -> some View {
        if items.isEmpty {
            emptyStateRow
        } else {
            Section("Your routines") {
                ForEach(items, id: \.persistentModelID) { routine in
                    RoutineListItem(
                        title: routine.name,
                        onStartNow: { startRoutineNow(routine) },
                        onScheduleToday: { scheduleForToday(routine) },
                        onRename: { nameEditor = .rename(routine) },
                        onDelete: { confirmDelete(routine) }
                    )
                }
            }
        }
    }

    private var emptyStateRow: some View {
        ContentUnavailableView(
            "No routines yet",
            systemImage: "list.bullet.rectangle.portrait",
            description: Text("Create your first routine to reuse it in your calendar or start it instantly.")
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.vertical, 24)
    }

    // MARK: - Toolbar / Sheets / Covers (extracted to reduce inference load)

    private var topToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { nameEditor = .create } label: { Image(systemName: "plus") }
                .accessibilityLabel("Create routine")
        }
    }

    private func nameEditorSheet(_ state: RoutineNameEditorState) -> some View {
        RoutineNameEditorSheet(
            title: state.title,
            initialName: state.initialName,
            saveButtonTitle: state.saveButtonTitle,
            onSave: { newName in saveRoutineName(state: state, newName: newName) },
            onCancel: { nameEditor = nil }
        )
    }

    private func sessionCover() -> some View {
        NavigationStack {
            if let launchedSession {
                WorkoutSessionScreen(session: launchedSession)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSessionCover = false
                                self.launchedSession = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close workout")
                        }
                    }
            } else {
                ProgressView()
            }
        }
    }

    // MARK: - Filtering

    private var filteredRoutines: [WorkoutRoutine] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return routines }
        return routines.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    // MARK: - Create / Rename

    private func saveRoutineName(state: RoutineNameEditorState, newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        switch state.kind {
        case .create:
            // ✅ If your WorkoutRoutine initializer differs, update THIS line.
            let r = WorkoutRoutine(name: name)
            modelContext.insert(r)
            try? modelContext.save()

        case .rename(let r):
            r.name = name
            try? modelContext.save()
        }

        nameEditor = nil
    }

    // MARK: - Delete

    private func confirmDelete(_ routine: WorkoutRoutine) {
        routineToDelete = routine
        showDeleteConfirm = true
    }

    private func deleteConfirmed() {
        guard let r = routineToDelete else { return }
        modelContext.delete(r)
        try? modelContext.save()
        routineToDelete = nil
    }

    // MARK: - Actions: start / schedule

    private func startRoutineNow(_ routine: WorkoutRoutine) {
        let start = Date()
        let end = Calendar.current.date(byAdding: .minute, value: 60, to: start)

        let activity = Activity(
            title: routine.name,
            startAt: start,
            endAt: end,
            laneHint: 0,
            kind: .workout,
            workoutRoutineId: routine.id
        )
        activity.status = .planned
        activity.completedAt = nil
        activity.isAllDay = false

        modelContext.insert(activity)

        do {
            let templates = WorkoutRoutineMapper.toExerciseTemplates(routine: routine)
            let session = WorkoutSessionFactory.makeSession(
                linkedActivityId: activity.id,
                sourceRoutineId: routine.id,
                sourceRoutineNameSnapshot: routine.name,
                exercises: templates,
                prefillActualsFromTargets: true
            )

            modelContext.insert(session)
            activity.workoutSessionId = session.id
            try modelContext.save()

            launchedSession = session
            showSessionCover = true
        } catch {
            assertionFailure("Failed to start routine workout: \(error)")
        }
    }

    private func scheduleForToday(_ routine: WorkoutRoutine) {
        let start = nextFullHour(after: Date())
        let end = Calendar.current.date(byAdding: .minute, value: 60, to: start)

        let a = Activity(
            title: routine.name,
            startAt: start,
            endAt: end,
            laneHint: 0,
            kind: .workout,
            workoutRoutineId: routine.id
        )
        a.status = .planned
        a.completedAt = nil
        a.isAllDay = false

        modelContext.insert(a)
        try? modelContext.save()
    }

    private func nextFullHour(after date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
        let startOfHour = cal.date(from: comps) ?? date
        return cal.date(byAdding: .hour, value: 1, to: startOfHour) ?? date
    }
}

//// MARK: - Row item (extracted: big win for compiler)
//
//private struct RoutineListItem: View {
//    let routine: WorkoutRoutine
//    let onStartNow: () -> Void
//    let onScheduleToday: () -> Void
//    let onRename: () -> Void
//    let onDelete: () -> Void
//
//    var body: some View {
//        RoutineRow(
//            title: routine.name,
//            onStartNow: onStartNow,
//            onScheduleToday: onScheduleToday
//        )
//        .contentShape(Rectangle())
//        .contextMenu {
//            Button(action: onStartNow) {
//                Label("Start now", systemImage: "play.fill")
//            }
//            Button(action: onScheduleToday) {
//                Label("Schedule for today", systemImage: "calendar.badge.plus")
//            }
//            Button(action: onRename) {
//                Label("Rename", systemImage: "pencil")
//            }
//            Button(role: .destructive, action: onDelete) {
//                Label("Delete", systemImage: "trash")
//            }
//        }
//        .swipeActions(edge: .leading, allowsFullSwipe: true) {
//            Button(action: onStartNow) {
//                Label("Start", systemImage: "play.fill")
//            }
//            .tint(.green)
//        }
//        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
//            Button(action: onRename) {
//                Label("Rename", systemImage: "pencil")
//            }
//            .tint(.blue)
//
//            Button(role: .destructive, action: onDelete) {
//                Label("Delete", systemImage: "trash")
//            }
//        }
//    }
//}
//
//
//
//// MARK: - Small UI components
//
//private struct RoutineRow: View {
//    let title: String
//    let onStartNow: () -> Void
//    let onScheduleToday: () -> Void
//
//    var body: some View {
//        HStack(spacing: 12) {
//            ZStack {
//                RoundedRectangle(cornerRadius: 10)
//                    .fill(.thinMaterial)
//                    .frame(width: 36, height: 36)
//
//                Image(systemName: "list.bullet.rectangle.portrait")
//                    .font(.system(size: 16, weight: .semibold))
//                    .symbolRenderingMode(.hierarchical)
//            }
//
//            Text(title)
//                .font(.body.weight(.semibold))
//
//            Spacer()
//
//            Button(action: onScheduleToday) {
//                Image(systemName: "calendar.badge.plus")
//                    .symbolRenderingMode(.hierarchical)
//            }
//            .buttonStyle(.borderless)
//            .accessibilityLabel("Schedule for today")
//
//            Button(action: onStartNow) {
//                Image(systemName: "play.fill")
//                    .symbolRenderingMode(.hierarchical)
//            }
//            .buttonStyle(.borderless)
//            .accessibilityLabel("Start now")
//        }
//        .padding(.vertical, 4)
//    }
//}

// MARK: - Name editor sheet

private struct RoutineNameEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialName: String
    let saveButtonTitle: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String

    init(
        title: String,
        initialName: String,
        saveButtonTitle: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.initialName = initialName
        self.saveButtonTitle = saveButtonTitle
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Routine name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saveButtonTitle) {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct RoutineNameEditorState: Identifiable {
    enum Kind {
        case create
        case rename(WorkoutRoutine)
    }

    let id = UUID()
    let kind: Kind

    static let create = RoutineNameEditorState(kind: .create)

    static func rename(_ routine: WorkoutRoutine) -> RoutineNameEditorState {
        RoutineNameEditorState(kind: .rename(routine))
    }

    var title: String {
        switch kind {
        case .create: return "New Routine"
        case .rename: return "Rename Routine"
        }
    }

    var initialName: String {
        switch kind {
        case .create: return ""
        case .rename(let r): return r.name
        }
    }

    var saveButtonTitle: String {
        switch kind {
        case .create: return "Create"
        case .rename: return "Save"
        }
    }
}
