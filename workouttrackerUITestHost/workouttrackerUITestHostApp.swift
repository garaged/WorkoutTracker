import SwiftUI
import SwiftData
import Foundation
import UIKit

@main
@MainActor
struct workouttrackerUITestHostApp: App {

    @StateObject private var goalPrefillStore = GoalPrefillStore()

    private let container: ModelContainer

    init() {
        let env = ProcessInfo.processInfo.environment

        // Keep UI tests deterministic.
        UIView.setAnimationsEnabled(false)

        // Reset UserDefaults for the host bundle when requested.
        if env["UITESTS"] == "1", env["UITESTS_RESET"] == "1",
           let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        do {
            let c = try ModelContainerFactory.makeInMemoryContainer()

            if env["UITESTS"] == "1" {
                let context = ModelContext(c)

                // Calendar-style UI tests expect data seeded up-front. DayTimelineScreen intentionally
                // does NOT auto-seed on the "calendar" route (to avoid hijacking navigation).
                if env["UITESTS_SEED"] == "1" {
                    try seedCalendarUITestDataIfNeeded(context: context)
                }

                if env["UITESTS_ACTIVE_SESSIONS"] == "1" {
                    try seedHomeActiveSessionsUITestDataIfNeeded(context: context)

                    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
                    let activeCount = sessions.filter { $0.status == .inProgress && $0.endedAt == nil }.count
                    if activeCount < 2 {
                        fatalError("UITESTS assertion failed: Expected at least 2 active WorkoutSession records for Home active-session tests.")
                    }
                }

                if env["UITESTS_ACTIVE_SESSIONS_SCROLL"] == "1" {
                    try seedHomeActiveSessionsScrollUITestDataIfNeeded(context: context)
                    try assertHomeActiveSessionsScrollSeed(context: context)
                }
            }

            self.container = c
        } catch {
            fatalError("UITestHost: failed to create/seed in-memory ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            UITestHostRootView()
                .environmentObject(goalPrefillStore)
        }
        .modelContainer(container)
    }
}

// MARK: - Calendar UITest seed
@MainActor
private func seedCalendarUITestDataIfNeeded(context: ModelContext, calendar: Calendar = .current) throws {
    // 1) Always import Starter Pack (idempotent) so Workout picker has routines.
    _ = try RoutineSeeder.importStarterPack(context: context)

    // ✅ Fail fast in UI tests if the starter pack import didn’t create routines.
    // This turns "mysterious empty picker" into an immediate, actionable failure.
    let routineCount = try context.fetchCount(FetchDescriptor<WorkoutRoutine>())
    if routineCount == 0 {
        fatalError("UITESTS assertion failed: Starter Pack import created 0 WorkoutRoutine records. Ensure RoutineSeeder.swift + workout models are included in workouttrackerUITestHost target.")
    }

    // 2) Seed a few timeline items used by smoke tests (idempotent by title).
    let todayStart = calendar.startOfDay(for: Date())

    func ensureActivity(title: String, start: Date, end: Date?, kind: ActivityKind, workoutRoutineId: UUID? = nil, isAllDay: Bool = false) throws {
        let existing = try context.fetch(
            FetchDescriptor<Activity>(
                predicate: #Predicate<Activity> { a in a.title == title }
            )
        )
        if !existing.isEmpty { return }

        let a = Activity(title: title, startAt: start, endAt: end, laneHint: 0, kind: kind, workoutRoutineId: workoutRoutineId)
        a.isAllDay = isAllDay
        a.dayKey = DayTimelineEntryScreen.dayKey(for: start)
        context.insert(a)
    }

    // Place seeded items near the current hour so DayTimelineScreen auto-scroll lands close.
    let now = Date()
    let comps = calendar.dateComponents([.hour, .minute], from: now)
    let hour = comps.hour ?? 9
    let minute = ((comps.minute ?? 0) / 5) * 5
    let nearNow = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: todayStart) ?? todayStart

    try ensureActivity(
        title: "UITest — Timed",
        start: nearNow,
        end: calendar.date(byAdding: .minute, value: 60, to: nearNow),
        kind: .generic
    )

    try ensureActivity(
        title: "UITest — All-day",
        start: todayStart,
        end: calendar.date(byAdding: .day, value: 1, to: todayStart),
        kind: .generic,
        workoutRoutineId: nil,
        isAllDay: true
    )

    // Seed one real workout activity for the cardio layout test.
    let starterCardio = try context.fetch(
        FetchDescriptor<WorkoutRoutine>(
            predicate: #Predicate<WorkoutRoutine> { r in
                r.name.localizedStandardContains("Cardio") && r.name.localizedStandardContains("Mobility")
            }
        )
    ).first

    if let starterCardio {
        try ensureActivity(
            title: "UITest — Seeded Starter Cardio",
            start: nearNow,
            end: calendar.date(byAdding: .minute, value: 45, to: nearNow),
            kind: .workout,
            workoutRoutineId: starterCardio.id
        )
    } else {
        fatalError("UITESTS assertion failed: Expected to find a Starter cardio routine after Starter Pack import.")
    }

    // Template (kept because other calendar tests may rely on it)
    let existingTemplates = try context.fetchCount(FetchDescriptor<TemplateActivity>())
    if existingTemplates == 0 {
        let recurrence = RecurrenceRule(kind: .daily, startDate: todayStart, endDate: nil, interval: 1, weekdays: [])
        let template = TemplateActivity(
            title: "UITest — Template",
            defaultStartMinute: 7 * 60,
            defaultDurationMinutes: 30,
            isEnabled: true,
            recurrence: recurrence,
            kind: .generic
        )
        context.insert(template)
    }

    try context.save()
}

// MARK: - Home active-session UITest seed
@MainActor
private func seedHomeActiveSessionsUITestDataIfNeeded(context: ModelContext, calendar: Calendar = .current) throws {
    let existing = try context.fetch(FetchDescriptor<WorkoutSession>())
    if existing.contains(where: { $0.sourceRoutineNameSnapshot == "UITest — Active Today" || $0.sourceRoutineNameSnapshot == "UITest — Active Previous Day" }) {
        return
    }

    let now = Date()
    let today = WorkoutSession(
        startedAt: calendar.date(byAdding: .minute, value: -35, to: now) ?? now,
        sourceRoutineNameSnapshot: "UITest — Active Today"
    )
    today.status = .inProgress

    let yesterdayBase = calendar.date(byAdding: .day, value: -1, to: now) ?? now
    let yesterdayStart = calendar.date(bySettingHour: 18, minute: 10, second: 0, of: yesterdayBase) ?? yesterdayBase
    let previousDay = WorkoutSession(
        startedAt: yesterdayStart,
        sourceRoutineNameSnapshot: "UITest — Active Previous Day"
    )
    previousDay.status = .inProgress

    context.insert(today)
    context.insert(previousDay)

    try context.save()
}

// MARK: - Home active-session scroll UITest seed
@MainActor
private func seedHomeActiveSessionsScrollUITestDataIfNeeded(context: ModelContext, calendar: Calendar = .current) throws {
    // Reuse the real starter-pack → routine → template → session flow so the seeded
    // session behaves like a real workout session, including Continue targeting.
    _ = try RoutineSeeder.importStarterPack(context: context)

    let existing = try context.fetch(FetchDescriptor<WorkoutSession>())
    if existing.contains(where: { $0.sourceRoutineNameSnapshot == "UITest — Active Scroll" }) {
        return
    }

    let routines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
    guard !routines.isEmpty else {
        fatalError("UITESTS assertion failed: Expected Starter Pack routines before seeding scrollable active session.")
    }

    let rankedRoutines: [(routine: WorkoutRoutine, templateCount: Int)] = routines.compactMap { routine in
        let templates = WorkoutRoutineMapper.toExerciseTemplates(routine: routine)
        guard !templates.isEmpty else { return nil }
        return (routine, templates.count)
    }
    .sorted { lhs, rhs in
        if lhs.templateCount != rhs.templateCount { return lhs.templateCount > rhs.templateCount }
        return lhs.routine.name.localizedStandardCompare(rhs.routine.name) == .orderedAscending
    }

    guard let chosen = rankedRoutines.first else {
        fatalError("UITESTS assertion failed: Could not find any routine with exercise templates for scrollable active-session seed.")
    }

    let templates = WorkoutRoutineMapper.toExerciseTemplates(routine: chosen.routine)
    guard !templates.isEmpty else {
        fatalError("UITESTS assertion failed: Chosen routine '\(chosen.routine.name)' produced 0 exercise templates.")
    }

    let session = WorkoutSessionFactory.makeSession(
        linkedActivityId: nil,
        sourceRoutineId: chosen.routine.id,
        sourceRoutineNameSnapshot: "UITest — Active Scroll",
        exercises: templates,
        prefillActualsFromTargets: true
    )
    session.status = .inProgress

    let orderedExercises = session.exercises.sorted { $0.order < $1.order }
    let orderedSets = orderedExercises.flatMap { ex in
        ex.setLogs.sorted { $0.order < $1.order }
    }

    // We intentionally complete a couple of early sets so Resume/Continue has a meaningful
    // actionable target that is not the first row in the session.
    guard orderedSets.count >= 4 else {
        fatalError("UITESTS assertion failed: Scrollable active-session seed produced only \(orderedSets.count) set rows. Expected at least 4 for a meaningful centering test.")
    }

    let completedAt = calendar.date(byAdding: .minute, value: -15, to: Date()) ?? Date()
    for set in orderedSets.prefix(2) {
        set.completed = true
        set.completedAt = completedAt
    }

    context.insert(session)
    try context.save()
}

@MainActor
private func assertHomeActiveSessionsScrollSeed(context: ModelContext) throws {
    let sessions = try context.fetch(
        FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { s in
                s.sourceRoutineNameSnapshot == "UITest — Active Scroll"
            }
        )
    )

    guard let session = sessions.first else {
        fatalError("UITESTS assertion failed: Expected scrollable active session named 'UITest — Active Scroll'.")
    }

    guard session.status == .inProgress, session.endedAt == nil else {
        fatalError("UITESTS assertion failed: Scrollable active session must be in-progress and not ended.")
    }

    let orderedExercises = session.exercises.sorted { $0.order < $1.order }
    guard !orderedExercises.isEmpty else {
        fatalError("UITESTS assertion failed: Scrollable active session has 0 exercises.")
    }

    let orderedSets = orderedExercises.flatMap { ex in
        ex.setLogs.sorted { $0.order < $1.order }
    }

    guard orderedSets.count >= 4 else {
        fatalError("UITESTS assertion failed: Scrollable active session has only \(orderedSets.count) set rows. Expected at least 4.")
    }

    let incompleteCount = orderedSets.filter { !$0.completed }.count
    guard incompleteCount >= 1 else {
        fatalError("UITESTS assertion failed: Scrollable active session has no incomplete set rows to focus.")
    }

    let targetID = WorkoutContinueNavigator().nextTargetSetID(
        exercises: orderedExercises,
        activeExerciseID: nil,
        activeSetID: nil
    )

    guard let targetID else {
        fatalError("UITESTS assertion failed: Scrollable active session did not produce a Continue/Resume target set.")
    }

    let targetExists = orderedExercises.contains { ex in
        ex.setLogs.contains(where: { $0.id == targetID })
    }

    guard targetExists else {
        fatalError("UITESTS assertion failed: Computed actionable target set does not belong to the seeded session.")
    }
}
