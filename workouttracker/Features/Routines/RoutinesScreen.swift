import SwiftUI
import SwiftData

@MainActor
struct RoutinesScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @State private var searchText: String = ""

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
            // Create mode inserts immediately — prevent swipe-dismiss leaving an empty routine behind.
            .interactiveDismissDisabled(isCreatingRoutine)
        }
    }

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
                .contextMenu {
                    Button {
                        routineEditorMode = .edit(routine)
                        showRoutineEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        confirmDelete(routine)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    private func rowView(for routine: WorkoutRoutine) -> AnyView {
        let startNow: () -> Void = { startRoutineNow(routine) }
        let scheduleToday: () -> Void = { scheduleForToday(routine) }

        // Pro behavior: rename opens the full editor (name + items).
        let rename: () -> Void = {
            routineEditorMode = .edit(routine)
            showRoutineEditor = true
        }

        let delete: () -> Void = { confirmDelete(routine) }

        return AnyView(
            RoutineListItem(
                title: routine.name,
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

        do {
            modelContext.insert(activity)

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
}
