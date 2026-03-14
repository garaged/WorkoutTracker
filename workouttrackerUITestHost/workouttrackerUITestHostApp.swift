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

        if env["UITESTS"] == "1", env["UITESTS_REST_TIMER_SHORT"] == "1" {
            UserDefaults.standard.set(2, forKey: "prefs.defaultRestSeconds")
            UserDefaults.standard.set(true, forKey: "prefs.autoStartRest")
            UserDefaults.standard.set(true, forKey: "prefs.restTimerCueEnabled")
            UserDefaults.standard.set(true, forKey: "prefs.restTimerShowOverdue")
        }

        do {
            let c = try ModelContainerFactory.makeInMemoryContainer()

            if env["UITESTS"] == "1" {
                let context = ModelContext(c)

                // Calendar-style UI tests expect data seeded up-front. DayTimelineScreen intentionally
                // does NOT auto-seed on the "calendar" route (to avoid hijacking navigation).
                if env["UITESTS_SEED"] == "1" {
                    try seedCalendarUITestDataIfNeeded(context: context)

                    if env["UITESTS_LINKED_FLOW"] == "1" {
                        try seedLinkedRoutineUITestDataIfNeeded(context: context)
                        try assertLinkedRoutineUITestSeed(context: context)
                    }
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

// MARK: - Linked routine UITest seed
@MainActor
private func seedLinkedRoutineUITestDataIfNeeded(context: ModelContext) throws {
    let mainName = "UITest — Linked Main"

    let existingMain = try context.fetch(
        FetchDescriptor<WorkoutRoutine>(
            predicate: #Predicate<WorkoutRoutine> { routine in
                routine.name == mainName
            }
        )
    ).first

    if existingMain != nil {
        return
    }

    let warmExercise = Exercise(name: "UITest Warm-up Press")
    let mainExercise = Exercise(name: "UITest Main Bench")
    let coolExercise = Exercise(name: "UITest Cool-down Press")

    let warmRoutine = WorkoutRoutine(name: "UITest — Linked Warm-up")
    let mainRoutine = WorkoutRoutine(name: mainName)
    let coolRoutine = WorkoutRoutine(name: "UITest — Linked Cool-down")

    let warmItem = WorkoutRoutineItem(
        order: 0,
        routine: warmRoutine,
        exercise: warmExercise,
        trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
    )
    let mainItem = WorkoutRoutineItem(
        order: 0,
        routine: mainRoutine,
        exercise: mainExercise,
        trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
    )
    let coolItem = WorkoutRoutineItem(
        order: 0,
        routine: coolRoutine,
        exercise: coolExercise,
        trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
    )

    let warmPlan = WorkoutSetPlan(order: 0, targetReps: 12, targetWeight: 20, weightUnit: .kg, targetRPE: nil, restSeconds: 30, routineItem: warmItem)
    let mainPlan = WorkoutSetPlan(order: 0, targetReps: 5, targetWeight: 60, weightUnit: .kg, targetRPE: nil, restSeconds: 60, routineItem: mainItem)
    let coolPlan = WorkoutSetPlan(order: 0, targetReps: 10, targetWeight: 15, weightUnit: .kg, targetRPE: nil, restSeconds: 30, routineItem: coolItem)

    warmRoutine.items = [warmItem]
    mainRoutine.items = [mainItem]
    coolRoutine.items = [coolItem]

    warmItem.setPlans = [warmPlan]
    mainItem.setPlans = [mainPlan]
    coolItem.setPlans = [coolPlan]

    mainRoutine.warmUpRoutine = warmRoutine
    mainRoutine.coolDownRoutine = coolRoutine

    context.insert(warmExercise)
    context.insert(mainExercise)
    context.insert(coolExercise)

    context.insert(warmRoutine)
    context.insert(mainRoutine)
    context.insert(coolRoutine)

    context.insert(warmItem)
    context.insert(mainItem)
    context.insert(coolItem)

    context.insert(warmPlan)
    context.insert(mainPlan)
    context.insert(coolPlan)

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

@MainActor
private func assertLinkedRoutineUITestSeed(context: ModelContext) throws {
    let routines = try context.fetch(
        FetchDescriptor<WorkoutRoutine>(
            predicate: #Predicate<WorkoutRoutine> { routine in
                routine.name == "UITest — Linked Main" ||
                routine.name == "UITest — Linked Warm-up" ||
                routine.name == "UITest — Linked Cool-down"
            }
        )
    )

    let byName = Dictionary(uniqueKeysWithValues: routines.map { ($0.name, $0) })

    guard let main = byName["UITest — Linked Main"],
          let warm = byName["UITest — Linked Warm-up"],
          let cool = byName["UITest — Linked Cool-down"] else {
        fatalError("UITESTS assertion failed: linked-flow seed expected warm-up, main, and cool-down routines to exist.")
    }

    guard main.warmUpRoutine?.id == warm.id, main.coolDownRoutine?.id == cool.id else {
        fatalError("UITESTS assertion failed: linked-flow seed expected UITest — Linked Main to be linked to warm-up and cool-down routines.")
    }

    let segments = WorkoutRoutineMapper.toExecutionSegments(routine: main)
    let kinds = segments.map(\.kind)

    guard kinds == [.warmUp, .main, .coolDown] else {
        fatalError("UITESTS assertion failed: linked-flow seed expected warm-up -> main -> cool-down execution order.")
    }

    guard !segments.contains(where: { $0.exerciseItems.isEmpty }) else {
        fatalError("UITESTS assertion failed: linked-flow seed expected each execution segment to contain at least one routine item.")
    }
}
