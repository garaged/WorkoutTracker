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

        // Keep UI tests deterministic, but allow specific suites to opt back into animation-driven behavior.
        if env["UITESTS"] == "1" {
            let disableAnimations = env["UITESTS_DISABLE_ANIMATIONS"] != "0"
            UIView.setAnimationsEnabled(!disableAnimations ? true : false)
        }

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
            if env["UITESTS"] == "1" {
                assertUITestLaunchConfiguration(env)
            }

            let c = try ModelContainerFactory.makeInMemoryContainer()

            if env["UITESTS"] == "1" {
                let context = ModelContext(c)

                // Calendar-style UI tests expect data seeded up-front. DayTimelineScreen intentionally
                // does NOT auto-seed on the "calendar" route (to avoid hijacking navigation).
                if env["UITESTS_SEED"] == "1" {
                    try assertProgramCatalogUITestSeed()
                    try seedCalendarUITestDataIfNeeded(context: context)

                    if env["UITESTS_LINKED_FLOW"] == "1" {
                        try seedLinkedRoutineUITestDataIfNeeded(context: context)
                        try assertLinkedRoutineUITestSeed(context: context)
                    }

                    if env["UITESTS_PROGRESS"] == "1" {
                        try seedProgressUITestDataIfNeeded(context: context)
                        try assertProgressUITestSeed(context: context)
                    }

                    if env["UITESTS_PROGRESS_LOW_DATA"] == "1" {
                        try seedLowDataProgressUITestDataIfNeeded(context: context)
                        try assertLowDataProgressUITestSeed(context: context)
                    }
                }

                if env["UITESTS_LOCALIZATION"] == "1", env["UITESTS_SEED"] == "1" {
                    try assertLocalizationUITestSeed(context: context)
                }

                if env["UITESTS_THUMBNAILS"] == "1", env["UITESTS_SEED"] == "1" {
                    try assertExerciseThumbnailUITestSeed(context: context)
                }

                if env["UITESTS_ACTIVE_SESSIONS"] == "1" {
                    try seedHomeActiveSessionsUITestDataIfNeeded(context: context)

                    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
                    let activeSessions = sessions.filter { $0.status == .inProgress && $0.endedAt == nil }
                    if activeSessions.count < 2 {
                        fatalError("UITESTS assertion failed: Expected at least 2 active WorkoutSession records for Home active-session tests.")
                    }

                    let calendar = Calendar.current
                    let hasToday = activeSessions.contains { calendar.isDateInToday($0.startedAt) }
                    let hasPreviousDay = activeSessions.contains { calendar.startOfDay(for: $0.startedAt) < calendar.startOfDay(for: Date()) }
                    if !hasToday || !hasPreviousDay {
                        fatalError("UITESTS assertion failed: Home active-session seed must include one current-day and one previous-day unfinished session.")
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

private enum ProgressUITestSeed {
    static let primaryExerciseID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let secondaryExerciseID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let primaryExerciseName = "UITest Bench Press"
    static let secondaryExerciseName = "UITest Squat"
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

// MARK: - Progress UITest seed
@MainActor
private func seedProgressUITestDataIfNeeded(context: ModelContext, calendar: Calendar = .current) throws {
    let existing = try context.fetch(FetchDescriptor<WorkoutSession>())
        .filter { $0.status == .completed }

    if existing.contains(where: { session in
        session.exercises.contains(where: { $0.exerciseId == ProgressUITestSeed.primaryExerciseID })
    }) {
        return
    }

    let now = Date()

    let benchSeeds: [(daysAgo: Int, reps: [Int], weights: [Double], durationMinutes: Int)] = [
        (77, [8, 8, 8], [60, 60, 60], 42),
        (63, [8, 8, 8], [65, 65, 65], 44),
        (49, [6, 6, 6], [70, 70, 70], 46),
        (35, [6, 6, 6], [72.5, 72.5, 72.5], 47),
        (21, [5, 5, 5], [75, 75, 75], 49),
        (7, [5, 5, 5], [80, 80, 80], 50)
    ]

    let squatSeeds: [(daysAgo: Int, reps: [Int], weights: [Double], durationMinutes: Int)] = [
        (56, [5, 5, 5], [90, 90, 90], 45),
        (28, [5, 5, 5], [100, 100, 100], 47),
        (14, [5, 5, 5], [105, 105, 105], 48)
    ]

    for seed in benchSeeds {
        let startedAt = calendar.date(byAdding: .day, value: -seed.daysAgo, to: now) ?? now
        let session = makeCompletedStrengthSession(
            exerciseID: ProgressUITestSeed.primaryExerciseID,
            exerciseName: ProgressUITestSeed.primaryExerciseName,
            startedAt: startedAt,
            durationMinutes: seed.durationMinutes,
            reps: seed.reps,
            weights: seed.weights,
            calendar: calendar
        )
        context.insert(session)
    }

    for seed in squatSeeds {
        let startedAt = calendar.date(byAdding: .day, value: -seed.daysAgo, to: now) ?? now
        let session = makeCompletedStrengthSession(
            exerciseID: ProgressUITestSeed.secondaryExerciseID,
            exerciseName: ProgressUITestSeed.secondaryExerciseName,
            startedAt: startedAt,
            durationMinutes: seed.durationMinutes,
            reps: seed.reps,
            weights: seed.weights,
            calendar: calendar
        )
        context.insert(session)
    }

    try context.save()
}

@MainActor
private func seedLowDataProgressUITestDataIfNeeded(context: ModelContext, calendar: Calendar = .current) throws {
    let existing = try context.fetch(FetchDescriptor<WorkoutSession>())
        .filter { $0.status == .completed }

    if existing.contains(where: { session in
        session.exercises.contains(where: { $0.exerciseId == ProgressUITestSeed.primaryExerciseID })
    }) {
        return
    }

    let startedAt = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    let session = makeCompletedStrengthSession(
        exerciseID: ProgressUITestSeed.primaryExerciseID,
        exerciseName: ProgressUITestSeed.primaryExerciseName,
        startedAt: startedAt,
        durationMinutes: 35,
        reps: [8, 8],
        weights: [55, 55],
        calendar: calendar
    )

    context.insert(session)
    try context.save()
}

@MainActor
private func assertProgressUITestSeed(context: ModelContext, calendar: Calendar = .current) throws {
    let service = ProgressAnalyticsService(
        context: context,
        weeklyVolumeCalculator: WeeklyVolumeCalculator(calendar: calendar),
        consistencyCalculator: ConsistencyCalculator(calendar: calendar)
    )

    let end = calendar.startOfDay(for: Date())
    let start = calendar.date(byAdding: .day, value: -84, to: end) ?? end
    let dashboard = try service.dashboardSummary(for: DateInterval(start: start, end: end))

    guard dashboard.featuredExercises.contains(where: { $0.exerciseID == ProgressUITestSeed.primaryExerciseID }) else {
        fatalError("UITESTS assertion failed: Progress seed did not surface the primary featured exercise on the dashboard.")
    }

    guard dashboard.weeklySummary != nil else {
        fatalError("UITESTS assertion failed: Progress seed expected a weekly summary for the dashboard.")
    }

    let detail = try service.exerciseDetailSummary(
        for: ProgressUITestSeed.primaryExerciseID,
        window: DateInterval(start: start, end: end)
    )

    guard detail.personalRecords.count >= 1 else {
        fatalError("UITESTS assertion failed: Progress seed expected at least 1 personal record for the primary exercise.")
    }

    guard detail.recentPerformanceSamples.count >= 3 else {
        fatalError("UITESTS assertion failed: Progress seed expected at least 3 recent performance samples for the primary exercise.")
    }
}

@MainActor
private func assertLowDataProgressUITestSeed(context: ModelContext, calendar: Calendar = .current) throws {
    let service = ProgressAnalyticsService(
        context: context,
        weeklyVolumeCalculator: WeeklyVolumeCalculator(calendar: calendar),
        consistencyCalculator: ConsistencyCalculator(calendar: calendar)
    )

    let end = calendar.startOfDay(for: Date())
    let start = calendar.date(byAdding: .day, value: -84, to: end) ?? end
    let window = DateInterval(start: start, end: end)

    let dashboard = try service.dashboardSummary(for: window)

    guard dashboard.featuredExercises.contains(where: { $0.exerciseID == ProgressUITestSeed.primaryExerciseID }) else {
        fatalError("UITESTS assertion failed: Low-data Progress seed should still surface the seeded primary exercise on the dashboard.")
    }

    let detail = try service.exerciseDetailSummary(
        for: ProgressUITestSeed.primaryExerciseID,
        window: window
    )

    guard detail.hasLowData else {
        fatalError("UITESTS assertion failed: Low-data Progress seed should produce a low-data exercise detail state.")
    }
}

@MainActor
private func makeCompletedStrengthSession(
    exerciseID: UUID,
    exerciseName: String,
    startedAt: Date,
    durationMinutes: Int,
    reps: [Int],
    weights: [Double],
    calendar: Calendar
) -> WorkoutSession {
    let session = WorkoutSession(startedAt: startedAt)
    session.status = .completed
    session.endedAt = calendar.date(byAdding: .minute, value: durationMinutes, to: startedAt)

    let exercise = WorkoutSessionExercise(
        order: 0,
        exerciseId: exerciseID,
        exerciseNameSnapshot: exerciseName,
        trackingStyle: .strength,
        segment: .main,
        session: session
    )

    var logs: [WorkoutSetLog] = []
    var secondsOffset = 5 * 60

    for (index, rep) in reps.enumerated() {
        let completedAt = startedAt.addingTimeInterval(TimeInterval(secondsOffset))
        let log = WorkoutSetLog(
            order: index,
            origin: .planned,
            reps: rep,
            weight: weights[index],
            weightUnit: .kg,
            completed: true,
            completedAt: completedAt,
            targetReps: rep,
            targetWeight: weights[index],
            targetWeightUnit: .kg,
            targetRestSeconds: 120
        )
        logs.append(log)
        secondsOffset += 150
    }

    exercise.setLogs = logs
    session.exercises = [exercise]
    return session
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

    let dayStart = calendar.startOfDay(for: Date())
    let now = Date()
    let comps = calendar.dateComponents([.hour, .minute], from: now)
    let hour = comps.hour ?? 9
    let minute = ((comps.minute ?? 0) / 5) * 5
    let activityStart = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? now
    let activityEnd = calendar.date(byAdding: .minute, value: 60, to: activityStart)

    let activity = Activity(
        title: "UITest — Active Scroll",
        startAt: activityStart,
        endAt: activityEnd,
        laneHint: 0,
        kind: .workout,
        workoutRoutineId: chosen.routine.id
    )
    activity.dayKey = DayTimelineEntryScreen.dayKey(for: activityStart)

    let session = WorkoutSessionFactory.makeSession(
        linkedActivityId: activity.id,
        sourceRoutineId: chosen.routine.id,
        sourceRoutineNameSnapshot: "UITest — Active Scroll",
        exercises: templates,
        prefillActualsFromTargets: true
    )
    session.status = .inProgress
    activity.workoutSessionId = session.id

    let orderedExercises = session.exercises.sorted { $0.order < $1.order }
    let orderedSets = orderedExercises.flatMap { ex in
        ex.setLogs.sorted { $0.order < $1.order }
    }

    // This seed exists specifically to protect cross-exercise scrolling regressions.
    // We deliberately complete every set that appears before a later exercise card so the
    // planner target is not in the first card and has several rows ahead of it.
    guard orderedExercises.count >= 2 else {
        fatalError("UITESTS assertion failed: Scrollable active-session seed produced only \(orderedExercises.count) exercise card(s). Expected at least 2 so Resume must jump to a later exercise.")
    }

    guard orderedSets.count >= 6 else {
        fatalError("UITESTS assertion failed: Scrollable active-session seed produced only \(orderedSets.count) set rows. Expected at least 6 for a meaningful off-screen resume target.")
    }

    let exerciseSetRows = orderedExercises.map { ex in
        ex.setLogs.sorted { $0.order < $1.order }
    }

    var cumulativeBeforeExercise = 0
    var targetExerciseIndex: Int?
    for (index, sets) in exerciseSetRows.enumerated() {
        guard !sets.isEmpty else { continue }
        if index > 0 && cumulativeBeforeExercise >= 4 {
            targetExerciseIndex = index
        }
        cumulativeBeforeExercise += sets.count
    }

    guard let resolvedTargetExerciseIndex = targetExerciseIndex else {
        fatalError("UITESTS assertion failed: Scrollable active-session seed could not place the planner target in a later exercise with at least 4 preceding set rows.")
    }

    let completedAt = calendar.date(byAdding: .minute, value: -15, to: Date()) ?? Date()
    for sets in exerciseSetRows.prefix(resolvedTargetExerciseIndex) {
        for set in sets {
            set.completed = true
            set.completedAt = completedAt
        }
    }

    context.insert(activity)
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
    guard orderedExercises.count >= 2 else {
        fatalError("UITESTS assertion failed: Scrollable active session has only \(orderedExercises.count) exercise card(s). Expected at least 2.")
    }

    let orderedSets = orderedExercises.flatMap { ex in
        ex.setLogs.sorted { $0.order < $1.order }
    }

    guard orderedSets.count >= 6 else {
        fatalError("UITESTS assertion failed: Scrollable active session has only \(orderedSets.count) set rows. Expected at least 6.")
    }

    let incompleteCount = orderedSets.filter { !$0.completed }.count
    guard incompleteCount >= 1 else {
        fatalError("UITESTS assertion failed: Scrollable active session has no incomplete set rows to focus.")
    }

    let plannerTarget = SessionResumePlanner().target(for: session)

    guard let targetID = plannerTarget?.setID else {
        fatalError("UITESTS assertion failed: Scrollable active session did not produce a planner target set.")
    }

    var targetExerciseIndex: Int?
    var precedingSetCount = 0
    for (index, exercise) in orderedExercises.enumerated() {
        let sets = exercise.setLogs.sorted { $0.order < $1.order }
        if sets.contains(where: { $0.id == targetID }) {
            targetExerciseIndex = index
            break
        }
        precedingSetCount += sets.count
    }

    guard let resolvedTargetExerciseIndex = targetExerciseIndex else {
        fatalError("UITESTS assertion failed: Planner target set does not belong to the seeded session.")
    }

    guard resolvedTargetExerciseIndex > 0 else {
        fatalError("UITESTS assertion failed: Scrollable active-session seed should target a later exercise card, not the first one.")
    }

    guard precedingSetCount >= 4 else {
        fatalError("UITESTS assertion failed: Scrollable active-session seed should leave at least 4 set rows before the planner target so Resume must scroll meaningfully.")
    }

    guard session.linkedActivityId != nil else {
        fatalError("UITESTS assertion failed: Scrollable active session should be linked to a workout Activity so Home and Day resume test the same session.")
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

    guard main.warmUpRoutine?.id == warm.id else {
        fatalError("UITESTS assertion failed: linked-flow seed expected main routine to reference the warm-up routine.")
    }

    guard main.coolDownRoutine?.id == cool.id else {
        fatalError("UITESTS assertion failed: linked-flow seed expected main routine to reference the cool-down routine.")
    }
}


@MainActor
private func assertUITestLaunchConfiguration(_ env: [String: String]) {
    let start = (env["UITESTS_START"] ?? "calendar").lowercased()
    let progressModes = [env["UITESTS_PROGRESS"] == "1", env["UITESTS_PROGRESS_LOW_DATA"] == "1"].filter { $0 }.count
    if progressModes > 1 {
        fatalError("UITESTS assertion failed: Choose only one Progress seed mode. UITESTS_PROGRESS and UITESTS_PROGRESS_LOW_DATA are mutually exclusive.")
    }

    let activeSessionModes = [env["UITESTS_ACTIVE_SESSIONS"] == "1", env["UITESTS_ACTIVE_SESSIONS_SCROLL"] == "1"].filter { $0 }.count
    if activeSessionModes > 1 {
        fatalError("UITESTS assertion failed: Choose only one Home active-session seed mode. UITESTS_ACTIVE_SESSIONS and UITESTS_ACTIVE_SESSIONS_SCROLL are mutually exclusive.")
    }

    if (env["UITESTS_PROGRESS"] == "1" || env["UITESTS_PROGRESS_LOW_DATA"] == "1") && start != "progress" {
        fatalError("UITESTS assertion failed: Progress seed modes must launch with UITESTS_START=progress.")
    }

    if env["UITESTS_LINKED_FLOW"] == "1" && start != "session" && start != "home" {
        fatalError(
            """
            UITESTS assertion failed: Linked routine flow tests must launch with \
            UITESTS_START=session or UITESTS_START=home.
            """
        )
    }

    if env["UITESTS_DEEP_LINK_SMOKE"] == "1" {
        guard start == "home" else {
            fatalError("UITESTS assertion failed: Deep-link smoke test must launch with UITESTS_START=home.")
        }

        guard env["UITESTS_ACTIVE_SESSIONS_SCROLL"] == "1" else {
            fatalError("UITESTS assertion failed: Deep-link smoke test requires UITESTS_ACTIVE_SESSIONS_SCROLL=1 so the host can build a deterministic session-exercise route.")
        }
    }

    let needsSeededData = start == "session" || env["UITESTS_PROGRESS"] == "1" || env["UITESTS_PROGRESS_LOW_DATA"] == "1" || env["UITESTS_LINKED_FLOW"] == "1"
    if needsSeededData, env["UITESTS_SEED"] != "1" {
        fatalError("UITESTS assertion failed: Session and Progress UITest routes require UITESTS_SEED=1 so starter-pack and scenario data are available.")
    }

    if env["UITESTS_LOCALIZATION"] == "1" {
        let needsLocalizedSeededData = env["UITESTS_PROGRESS"] == "1" || env["UITESTS_PROGRESS_LOW_DATA"] == "1" || env["UITESTS_LINKED_FLOW"] == "1"
        let exerciseBrowseStarts = start == "exercise-library" || start == "exercise-picker"
        if (needsLocalizedSeededData || exerciseBrowseStarts), env["UITESTS_SEED"] != "1" {
            fatalError("UITESTS assertion failed: Localization smoke tests that cover seeded browse, Progress, or linked-session flows must launch with UITESTS_SEED=1.")
        }
    }

    if env["UITESTS_THUMBNAILS"] == "1", env["UITESTS_SEED"] != "1" {
        fatalError("UITESTS assertion failed: Thumbnail smoke tests require UITESTS_SEED=1 so image-capable catalog exercises are available.")
    }
}


@MainActor
private func assertLocalizationUITestSeed(context: ModelContext) throws {
    let exercises = try context.fetch(FetchDescriptor<Exercise>())

    guard let benchPress = exercises.first(where: { $0.catalogKey == "bench-press" }) else {
        fatalError("UITESTS assertion failed: Localization seed should include a built-in Bench Press exercise with catalogKey=bench-press.")
    }

    let displayName = ExerciseLocalizationService.displayName(for: benchPress, locale: Locale(identifier: "es-MX"))
    guard displayName == "Press de banca" else {
        fatalError("UITESTS assertion failed: Bench Press should resolve to 'Press de banca' under es-MX localization smoke tests.")
    }
}

@MainActor
private func assertExerciseThumbnailUITestSeed(context: ModelContext) throws {
    let exercises = try context.fetch(FetchDescriptor<Exercise>())

    guard let benchPress = exercises.first(where: { $0.catalogKey == "bench-press" }) else {
        fatalError("UITESTS assertion failed: Thumbnail seed should include a built-in Bench Press exercise with catalogKey=bench-press.")
    }

    guard let assetName = ExerciseImageResolver.assetName(for: benchPress, illustrationSet: .dummyV1), !assetName.isEmpty else {
        fatalError("UITESTS assertion failed: Seeded Bench Press exercise should resolve to a bundled illustration asset for thumbnail smoke tests.")
    }
}

@MainActor
private func assertProgramCatalogUITestSeed() throws {
    let catalog = try ProgramCatalogService().loadCatalog()
    guard let pack = catalog.packV2 else {
        fatalError("UITESTS assertion failed: seeded program catalog should decode as a V2 pack.")
    }

    guard pack.programs.contains(where: { $0.slug == "seed-program-v2" }) else {
        fatalError("UITESTS assertion failed: seeded program catalog must include seed-program-v2.")
    }

    guard let goblet = pack.exercises.first(where: { ProgramPackHelpers.normalizedSlug($0.slug) == "goblet-squat" }) else {
        fatalError("UITESTS assertion failed: seeded program catalog must include goblet-squat exercise metadata.")
    }

    guard ProgramPackHelpers.normalizedCatalogKey(goblet.catalogKey) == "goblet-squat" else {
        fatalError("UITESTS assertion failed: seeded program catalog should carry catalog_key for goblet-squat.")
    }

    let hasRoutineReference = pack.routines.contains { routine in
        routine.items.contains { ProgramPackHelpers.normalizedSlug($0.exerciseSlug) == "goblet-squat" }
    }
    guard hasRoutineReference else {
        fatalError("UITESTS assertion failed: seeded program routine must reference goblet-squat by stable exercise slug.")
    }
}
