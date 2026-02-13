import SwiftUI
import SwiftData

// File: workouttracker/Features/Routines/RoutinesScreen.swift
//
// Fixes the errors you reported:
//
// 1) "Cannot assign to value: 'launchedSession' is a 'let' constant"
//    - This happens when you do `if let launchedSession { ... }` and then try to set
//      `launchedSession = nil` inside that scope. The `if let` creates a shadowed constant.
//    - Fix: use `if let session = launchedSession { ... }` and mutate the @State optional.
//
// 2) "'nil' cannot be assigned to type 'WorkoutSession'"
//    - Your @State must be optional to be able to set it to nil.
//    - Fix: `@State private var launchedSession: WorkoutSession? = nil`
//
// 3) RoutineListItem initializer mismatch
//    - Your existing RoutineListItem.swift expects `title:` (String), not `routine:`.
//    - Fix: call `RoutineListItem(title: routine.name, ...)`
//
// 4) Still resilient against SwiftUI type-checker timeouts
//    - Hard fix: type-erase each row with AnyView via `rowView(for:)`
//
// This file does NOT redefine RoutineListItem/RoutineRow (so no duplicates).

@MainActor
struct RoutinesScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @State private var searchText: String = ""
    @State private var nameEditor: NameEditorState? = nil

    @State private var routineToDelete: WorkoutRoutine? = nil
    @State private var showDeleteConfirm: Bool = false

    // Start-now flow
    @State private var launchedSession: WorkoutSession? = nil
    @State private var showSessionCover: Bool = false

    // Schedule feedback + navigation
    @State private var scheduledMessage: String = ""
    @State private var showScheduledAlert: Bool = false
    @State private var navToCalendar: Bool = false
    @State private var calendarInitialDay: Date = Date()
    // Full routine editor (name + exercises)
    @State private var showRoutineEditor: Bool = false
    @State private var routineEditorMode: RoutineEditorScreen.Mode = .create

    private var isCreatingRoutine: Bool {
        if case .create = routineEditorMode { return true }
        return false
    }

    private var filteredRoutines: [WorkoutRoutine] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return routines }
        return routines.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        // ✅ Explicit type helps the compiler.
        let data: [WorkoutRoutine] = filteredRoutines

        List {
            if data.isEmpty {
                emptyState
            } else {
                routinesSection(data)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search routines")
        .toolbar { toolbarContent }
        .navigationDestination(isPresented: $navToCalendar) {
            DayTimelineEntryScreen(initialDay: calendarInitialDay)
        }
        .alert("Scheduled", isPresented: $showScheduledAlert) {
            Button("Open Calendar") { navToCalendar = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text(scheduledMessage)
        }
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
        .fullScreenCover(isPresented: $showSessionCover) {
            NavigationStack {
                if let session = launchedSession {
                    WorkoutSessionScreen(session: session)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    showSessionCover = false
                                    launchedSession = nil
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
        .sheet(isPresented: $showRoutineEditor) {
            NavigationStack {
                RoutineEditorScreen(mode: routineEditorMode)
            }
            // important: create-mode inserts a new routine immediately
            .interactiveDismissDisabled(isCreatingRoutine)
        }
    }

    // MARK: - Pieces (split up to reduce generic complexity)

    private var emptyState: some View {
        ContentUnavailableView(
            "No routines yet",
            systemImage: "list.bullet.rectangle.portrait",
            description: Text("Create your first routine to reuse it in your calendar or start it instantly.")
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private func routinesSection(_ data: [WorkoutRoutine]) -> some View {
        ForEach(data) { routine in
            rowView(for: routine)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        routineEditorMode = .edit(routine)
                        showRoutineEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
        }
    }

    /// Type-erased row. This is the “hard fix” for stubborn type-checker timeouts.
    private func rowView(for routine: WorkoutRoutine) -> AnyView {
        let startNow: () -> Void = { startRoutineNow(routine) }
        let scheduleToday: () -> Void = { scheduleForToday(routine) }
        let rename: () -> Void = {
            routineEditorMode = .edit(routine)
            showRoutineEditor = true
        }
        let delete: () -> Void = { confirmDelete(routine) }

        return AnyView(
            RoutineListItem(
                title: routine.name,     // ✅ matches RoutineListItem.swift
                onStartNow: startNow,
                onScheduleToday: scheduleToday,
                onRename: rename,
                onDelete: delete
            )
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink {
                TemplatesScreen(applyDay: Calendar.current.startOfDay(for: Date()))
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .accessibilityLabel("Templates")

            Button {
                routineEditorMode = .create
                showRoutineEditor = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Create routine")
        }
    }

    // MARK: - Create / Rename

    private func saveRoutineName(state: NameEditorState, newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        switch state.kind {
        case .create:
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
        let cal = Calendar.current
        let start = Date()
        let end = cal.date(byAdding: .minute, value: 60, to: start)

        let activity = Activity(
            title: routine.name,
            startAt: start,
            endAt: end,
            laneHint: 0,
            kind: .workout,
            workoutRoutineId: routine.id
        )
        activity.dayKey = dayKey(for: start)
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
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)!

        // Keep it today + rounded (5 min)
        let rounded = roundUp(now, toMinutes: 5)
        let start = min(rounded, todayEnd.addingTimeInterval(-60))

        let end = cal.date(byAdding: .minute, value: 60, to: start)

        let a = Activity(
            title: routine.name,
            startAt: start,
            endAt: end,
            laneHint: 0,
            kind: .workout,
            workoutRoutineId: routine.id
        )
        a.dayKey = dayKey(for: start)
        a.status = .planned
        a.completedAt = nil
        a.isAllDay = false

        modelContext.insert(a)
        try? modelContext.save()

        scheduledMessage = "“\(routine.name)” scheduled for \(start.formatted(.dateTime.hour().minute()))."
        showScheduledAlert = true
        calendarInitialDay = todayStart
    }

    // MARK: - Helpers

    private func roundUp(_ date: Date, toMinutes step: Int) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let base = cal.date(from: comps), let minute = comps.minute else { return date }

        let rem = minute % step
        let add = (rem == 0) ? 0 : (step - rem)
        return cal.date(byAdding: .minute, value: add, to: base) ?? date
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func dayKey(for date: Date) -> String {
        let start = Calendar.current.startOfDay(for: date)
        return Self.dayKeyFormatter.string(from: start)
    }

    // MARK: - Nested types (nested to avoid module-wide name collisions)

    private struct NameEditorState: Identifiable {
        enum Kind {
            case create
            case rename(WorkoutRoutine)
        }

        let id = UUID()
        let kind: Kind

        static let create = NameEditorState(kind: .create)
        static func rename(_ r: WorkoutRoutine) -> NameEditorState { .init(kind: .rename(r)) }

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

    private struct NameEditorSheet: View {
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
}
