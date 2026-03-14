// workouttracker/Features/Routines/RoutinesScreen.swift
import SwiftUI
import SwiftData
import Foundation

@MainActor
struct RoutinesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.platform) private var platform

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @State private var searchText: String = ""

    // Delete confirmation
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

    // Canonical routine editor presentation
    @State private var presentedEditor: PresentedRoutineEditor? = nil

    private enum PresentedRoutineEditor: Identifiable {
        case create
        case edit(WorkoutRoutine)

        var id: String {
            switch self {
            case .create:
                return "create"
            case .edit(let routine):
                return "edit-\(routine.id.uuidString)"
            }
        }

        var mode: RoutineEditorScreen.Mode {
            switch self {
            case .create:
                return .create
            case .edit(let routine):
                return .edit(routine)
            }
        }

        var interactiveDismissDisabled: Bool {
            if case .create = self { return true }
            return false
        }
    }

    private var filteredRoutines: [WorkoutRoutine] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return routines }
        return routines.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        let data = filteredRoutines

        List {
            if data.isEmpty {
                ContentUnavailableView(
                    String(localized: "routines.empty.title"),
                    systemImage: "list.bullet.rectangle.portrait",
                    description: Text(String(localized: "routines.empty.message"))
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 24)
            } else {
                ForEach(data, id: \.id) { routine in
                    RoutineListItem(
                        title: routine.name,
                        badgeText: starterBadgeText(for: routine),
                        onStartNow: { startRoutineNow(routine) },
                        onScheduleToday: { scheduleForToday(routine) },
                        onEdit: { openEditor(for: routine) },
                        onDelete: { confirmDelete(routine) }
                    )
                }
            }
        }
        .readableWidth()
        .platformListChrome(platform)
        .navigationTitle(String(localized: "routines.title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: String(localized: "common.search.routines"))
        .toolbar { toolbarContent }
        .navigationDestination(isPresented: $navToCalendar) {
            DayTimelineEntryScreen(initialDay: calendarInitialDay)
        }
        .alert(String(localized: "routines.scheduled.title"), isPresented: $showScheduledAlert) {
            Button(String(localized: "routines.scheduled.open_calendar")) { navToCalendar = true }
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(scheduledMessage)
        }
        .confirmationDialog(
            String(localized: "routines.delete.confirmation.title"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete"), role: .destructive) { deleteConfirmed() }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "routines.delete.confirmation.message"))
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
                                .accessibilityLabel(AccessibilityLabels.Buttons.closeWorkout)
                            }
                        }
                } else {
                    ProgressView()
                }
            }
        }
        .sheet(item: $presentedEditor) { editor in
            NavigationStack {
                RoutineEditorScreen(mode: editor.mode)
            }
            .interactiveDismissDisabled(editor.interactiveDismissDisabled)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink {
                TemplatesScreen(applyDay: Calendar.current.startOfDay(for: Date()))
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .accessibilityLabel(AccessibilityLabels.Buttons.scheduleTemplates)

            Button {
                presentedEditor = .create
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(AccessibilityLabels.Buttons.createRoutine)
        }
    }

    private func openEditor(for routine: WorkoutRoutine) {
        presentedEditor = .edit(routine)
    }

    private func starterBadgeText(for routine: WorkoutRoutine) -> String? {
        routine.name.hasPrefix("Starter —") ? String(localized: "routines.row.starter_badge") : nil
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
        activity.dayKey = start.dayKey()

        do {
            modelContext.insert(activity)

            let session = try WorkoutSessionStarter.startOrResumeSession(
                for: activity,
                context: modelContext,
                now: start
            )

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
        a.dayKey = start.dayKey()
        a.status = .planned
        a.completedAt = nil
        a.isAllDay = false

        modelContext.insert(a)
        try? modelContext.save()

        scheduledMessage = String(format: String(localized: "routines.schedule.confirmation"), routine.name, AppFormatting.time(start))
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
}
