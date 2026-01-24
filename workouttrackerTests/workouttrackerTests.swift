import XCTest
import SwiftData
@testable import workouttracker

// MARK: - Test Support

enum TestSupport {

    /// Small wrapper that keeps a `ModelContainer` alive for the whole test.
    ///
    /// Why this exists:
    /// In practice, a `ModelContext` does **not** reliably retain its container
    /// strongly. If a helper returns only a `ModelContext` built from a local
    /// `ModelContainer`, the container can be deallocated as soon as the helper
    /// returns, and the first `context.insert(...)` will crash.
    struct InMemoryStore {
        let container: ModelContainer

        @MainActor
        var context: ModelContext { container.mainContext }
    }
    static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, calendar: Calendar = TestSupport.utcCalendar) -> Date {
        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        comps.second = 0
        return calendar.date(from: comps)!
    }

    @MainActor
    static func makeInMemoryStore() throws -> InMemoryStore {
        let schema = Schema([
            // Scheduling
            Activity.self,
            TemplateActivity.self,
            TemplateInstanceOverride.self,

            // Workouts domain
            Exercise.self,
            WorkoutRoutine.self,
            WorkoutRoutineItem.self,
            WorkoutSetPlan.self,
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            WorkoutSetLog.self,
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return InMemoryStore(container: container)
    }

    @MainActor
    static func insertRoutine(
        name: String = "Test Routine",
        exerciseName: String = "Bench Press",
        setPlans: [(reps: Int?, weight: Double?, rest: Int?)] = [(10, 100.0, 120), (10, 100.0, 120)],
        context: ModelContext
    ) throws -> WorkoutRoutine {
        let ex = Exercise(name: exerciseName)
        context.insert(ex)

        let routine = WorkoutRoutine(name: name)
        context.insert(routine)

        let item = WorkoutRoutineItem(order: 0, routine: routine, exercise: ex)
        context.insert(item)
        routine.items.append(item)

        for (idx, sp) in setPlans.enumerated() {
            let plan = WorkoutSetPlan(order: idx, targetReps: sp.reps, targetWeight: sp.weight, weightUnit: .kg, targetRPE: nil, restSeconds: sp.rest, routineItem: item)
            context.insert(plan)
            item.setPlans.append(plan)
        }

        try context.save()
        return routine
    }
}

// MARK: - Unit tests

final class RecurrenceRuleTests: XCTestCase {

    func test_noneMatchesOnlyStartDay() {
        let cal = TestSupport.utcCalendar
        let start = TestSupport.date(2026, 1, 10, calendar: cal)
        let rule = RecurrenceRule(kind: .none, startDate: start, endDate: nil, interval: 1, weekdays: [])

        XCTAssertTrue(rule.matches(day: start, calendar: cal))
        XCTAssertFalse(rule.matches(day: TestSupport.date(2026, 1, 11, calendar: cal), calendar: cal))
    }

    func test_dailyRespectsInterval() {
        let cal = TestSupport.utcCalendar
        let start = TestSupport.date(2026, 1, 1, calendar: cal)
        let rule = RecurrenceRule(kind: .daily, startDate: start, endDate: nil, interval: 2, weekdays: [])

        XCTAssertTrue(rule.matches(day: TestSupport.date(2026, 1, 1, calendar: cal), calendar: cal))
        XCTAssertFalse(rule.matches(day: TestSupport.date(2026, 1, 2, calendar: cal), calendar: cal))
        XCTAssertTrue(rule.matches(day: TestSupport.date(2026, 1, 3, calendar: cal), calendar: cal))
    }

    func test_weeklyMatchesSelectedWeekdays() {
        let cal = TestSupport.utcCalendar
        // 2026-01-05 is a Monday
        let start = TestSupport.date(2026, 1, 5, calendar: cal)
        let rule = RecurrenceRule(
            kind: .weekly,
            startDate: start,
            endDate: nil,
            interval: 1,
            weekdays: [.monday, .wednesday]
        )

        XCTAssertTrue(rule.matches(day: TestSupport.date(2026, 1, 5, calendar: cal), calendar: cal))  // Mon
        XCTAssertFalse(rule.matches(day: TestSupport.date(2026, 1, 6, calendar: cal), calendar: cal)) // Tue
        XCTAssertTrue(rule.matches(day: TestSupport.date(2026, 1, 7, calendar: cal), calendar: cal))  // Wed
    }
}

@MainActor
final class ActivityTimeRulesTests: XCTestCase {

    func test_setAllDayNormalizesToMidnightAndEndsNextMidnight() {
        let cal = TestSupport.utcCalendar
        let start = TestSupport.date(2026, 1, 10, 15, 30, calendar: cal)
        let a = Activity(title: "X", startAt: start, endAt: nil)

        ActivityTimeRules.setAllDay(a, calendar: cal)

        XCTAssertTrue(a.isAllDay)
        XCTAssertEqual(a.startAt, TestSupport.date(2026, 1, 10, 0, 0, calendar: cal))
        XCTAssertEqual(a.endAt, TestSupport.date(2026, 1, 11, 0, 0, calendar: cal))
    }

    func test_unsetAllDayTurns24hSpanIntoDefaultDuration() {
        let cal = TestSupport.utcCalendar
        let start = TestSupport.date(2026, 1, 10, 0, 0, calendar: cal)
        let a = Activity(title: "X", startAt: start, endAt: TestSupport.date(2026, 1, 11, 0, 0, calendar: cal))
        a.isAllDay = true

        ActivityTimeRules.unsetAllDay(a, defaultDurationMinutes: 30, calendar: cal)

        XCTAssertFalse(a.isAllDay)
        XCTAssertEqual(a.endAt, TestSupport.date(2026, 1, 10, 0, 30, calendar: cal))
    }

    func test_ensureEndAfterStartFixesInvalidEnd() {
        let cal = TestSupport.utcCalendar
        let start = TestSupport.date(2026, 1, 10, 10, 0, calendar: cal)
        let a = Activity(title: "X", startAt: start, endAt: TestSupport.date(2026, 1, 10, 9, 0, calendar: cal))

        ActivityTimeRules.ensureEndAfterStart(a, defaultDurationMinutes: 45, calendar: cal)

        XCTAssertEqual(a.endAt, TestSupport.date(2026, 1, 10, 10, 45, calendar: cal))
    }
}

final class DayActivityBucketerTests: XCTestCase {

    func test_bucketSeparatesAllDayMultiDayAndTimed() {
        let cal = TestSupport.utcCalendar
        let dayStart = TestSupport.date(2026, 1, 10, calendar: cal)
        let dayEnd = TestSupport.date(2026, 1, 11, calendar: cal)

        // Timed inside the day
        let timed = Activity(title: "Timed", startAt: TestSupport.date(2026, 1, 10, 9, 0, calendar: cal), endAt: TestSupport.date(2026, 1, 10, 10, 0, calendar: cal))

        // Explicit all-day (single-day)
        let allDay = Activity(title: "All", startAt: dayStart, endAt: dayEnd)
        allDay.isAllDay = true

        // Multi-day spanning previous -> today
        let multi = Activity(title: "Multi", startAt: TestSupport.date(2026, 1, 9, 23, 0, calendar: cal), endAt: TestSupport.date(2026, 1, 10, 1, 0, calendar: cal))

        let buckets = DayActivityBucketer.bucket(
            activities: [timed, allDay, multi],
            dayStart: dayStart,
            defaultDurationMinutes: 30,
            calendar: cal
        )

        XCTAssertEqual(buckets.timed.map { $0.title }, ["Timed"])
        XCTAssertEqual(buckets.allDay.map { $0.title }, ["All"])
        XCTAssertEqual(buckets.multiDay.map { $0.title }, ["Multi"])

        // Sanity: everything overlaps the day
        XCTAssertTrue(timed.startAt >= dayStart && (timed.endAt ?? timed.startAt) <= dayEnd)
    }
}

final class WorkoutSessionFactoryTests: XCTestCase {

    func test_makeSessionBuildsOrderedExercisesAndPrefillsTargetsIntoActuals() {
        let ex1 = WorkoutSessionFactory.ExerciseTemplate(
            order: 1,
            exerciseId: UUID(),
            nameSnapshot: "B",
            notes: nil,
            sets: [
                .init(order: 1, targetReps: 8, targetWeight: 100, targetWeightUnit: .kg, targetRPE: 7.5, targetRestSeconds: 120),
                .init(order: 0, targetReps: 10, targetWeight: 90, targetWeightUnit: .kg, targetRPE: 7.0, targetRestSeconds: 120)
            ]
        )

        let ex0 = WorkoutSessionFactory.ExerciseTemplate(
            order: 0,
            exerciseId: UUID(),
            nameSnapshot: "A",
            notes: nil,
            sets: [
                .init(order: 0, targetReps: 5, targetWeight: 120, targetWeightUnit: .kg, targetRPE: 8.0, targetRestSeconds: 180)
            ]
        )

        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutSessionFactory.makeSession(
            startedAt: startedAt,
            linkedActivityId: UUID(),
            sourceRoutineId: UUID(),
            sourceRoutineNameSnapshot: "R",
            exercises: [ex1, ex0],
            prefillActualsFromTargets: true
        )

        XCTAssertEqual(session.startedAt, startedAt)
        XCTAssertEqual(session.exercises.map { $0.order }, [0, 1])
        XCTAssertEqual(session.exercises.map { $0.exerciseNameSnapshot }, ["A", "B"])

        let b = session.exercises[1]
        XCTAssertEqual(b.setLogs.map { $0.order }, [0, 1])
        XCTAssertEqual(b.setLogs[0].reps, 10)
        XCTAssertEqual(b.setLogs[0].weight, 90)
        XCTAssertEqual(b.setLogs[0].targetReps, 10)
        XCTAssertEqual(b.setLogs[0].targetWeight, 90)
    }
}

final class WorkoutSessionTimerTests: XCTestCase {

    func test_pauseResumeAffectsElapsedSeconds() {
        let start = Date(timeIntervalSince1970: 1_000)
        let s = WorkoutSession(startedAt: start)

        // At t=1100: 100s elapsed
        XCTAssertEqual(s.elapsedSeconds(at: Date(timeIntervalSince1970: 1_100)), 100)

        // Pause at 1120 and check that elapsed freezes
        s.pause(at: Date(timeIntervalSince1970: 1_120))
        XCTAssertTrue(s.isPaused)
        XCTAssertEqual(s.elapsedSeconds(at: Date(timeIntervalSince1970: 1_150)), 120) // total 150s - paused(30s)

        // Resume at 1150, then at 1180 total elapsed = (180) - paused(30)
        s.resume(at: Date(timeIntervalSince1970: 1_150))
        XCTAssertFalse(s.isPaused)
        XCTAssertEqual(s.elapsedSeconds(at: Date(timeIntervalSince1970: 1_180)), 150)
    }
}

// MARK: - Integration tests (SwiftData + services)

@MainActor
final class WorkoutSessionStarterIntegrationTests: XCTestCase {

    func test_startOrResumeSession_createsSessionFromRoutineAndLinksActivity() throws {
        let cal = TestSupport.utcCalendar
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let routine = try TestSupport.insertRoutine(context: context)

        let start = TestSupport.date(2026, 1, 10, 9, 0, calendar: cal)
        let end = TestSupport.date(2026, 1, 10, 10, 0, calendar: cal)
        let a = Activity(title: "Workout", startAt: start, endAt: end, laneHint: 0, kind: .workout)
        a.workoutRoutineId = routine.id
        context.insert(a)
        try context.save()

        let now = TestSupport.date(2026, 1, 10, 9, 5, calendar: cal)
        let session = try WorkoutSessionStarter.startOrResumeSession(for: a, context: context, now: now)

        XCTAssertEqual(a.workoutSessionId, session.id)
        XCTAssertEqual(session.linkedActivityId, a.id)
        XCTAssertEqual(session.sourceRoutineId, routine.id)
        XCTAssertEqual(session.sourceRoutineNameSnapshot, routine.name)
        XCTAssertEqual(session.status, .inProgress)

        XCTAssertEqual(session.exercises.count, 1)
        XCTAssertEqual(session.exercises[0].setLogs.count, 2)
        XCTAssertEqual(session.exercises[0].setLogs[0].targetReps, 10)
        XCTAssertEqual(session.exercises[0].setLogs[0].reps, 10) // prefilled actual
    }

    func test_startOrResumeSession_resumesExistingLinkedSession() throws {
        let cal = TestSupport.utcCalendar
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let start = TestSupport.date(2026, 1, 10, 9, 0, calendar: cal)
        let a = Activity(title: "Workout", startAt: start, endAt: nil, laneHint: 0, kind: .workout)
        context.insert(a)

        let existing = WorkoutSession(startedAt: start, sourceRoutineId: nil, sourceRoutineNameSnapshot: nil, linkedActivityId: a.id)
        context.insert(existing)
        a.workoutSessionId = existing.id
        try context.save()

        let resumed = try WorkoutSessionStarter.startOrResumeSession(for: a, context: context, now: TestSupport.date(2026, 1, 10, 9, 1, calendar: cal))
        XCTAssertEqual(resumed.id, existing.id)
    }
}

@MainActor
final class TemplatePreloaderIntegrationTests: XCTestCase {

    func test_ensureDayIsPreloaded_createsInstanceFromDailyTemplate() throws {
        let cal = TestSupport.utcCalendar
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let day = TestSupport.date(2026, 1, 10, calendar: cal)
        let recurrence = RecurrenceRule(kind: .daily, startDate: day, endDate: nil, interval: 1, weekdays: [])
        let t = TemplateActivity(title: "Morning", defaultStartMinute: 9 * 60, defaultDurationMinutes: 30, isEnabled: true, recurrence: recurrence)
        context.insert(t)
        try context.save()

        try TemplatePreloader.ensureDayIsPreloaded(for: day, context: context, calendar: cal)

        let acts = try context.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(acts.count, 1)
        let a = acts[0]

        XCTAssertEqual(a.templateId, t.id)
        XCTAssertEqual(a.title, "Morning")
        XCTAssertEqual(a.plannedTitle, "Morning")
        XCTAssertEqual(a.startAt, TestSupport.date(2026, 1, 10, 9, 0, calendar: cal))
        XCTAssertEqual(a.endAt, TestSupport.date(2026, 1, 10, 9, 30, calendar: cal))
    }

    func test_updateExistingUpcomingInstances_backfillsNilPlannedFieldsAndRespectsDivergence() throws {
        let cal = TestSupport.utcCalendar
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let fromDay = TestSupport.date(2026, 1, 10, calendar: cal)

        let recurrence = RecurrenceRule(kind: .daily, startDate: fromDay, endDate: nil, interval: 1, weekdays: [])
        let t = TemplateActivity(title: "Old", defaultStartMinute: 9 * 60, defaultDurationMinutes: 30, isEnabled: true, recurrence: recurrence)
        context.insert(t)
        try context.save()

        // Older-style instance #1: nil planned fields but actuals match old planned => should update actuals.
        let d1 = TestSupport.date(2026, 1, 11, calendar: cal)
        let a1Start = TestSupport.date(2026, 1, 11, 9, 0, calendar: cal)
        let a1 = Activity(title: "Old", startAt: a1Start, endAt: TestSupport.date(2026, 1, 11, 9, 30, calendar: cal))
        a1.templateId = t.id
        a1.dayKey = d1.dayKey(calendar: cal)
        a1.generatedKey = "\(t.id.uuidString)|\(a1.dayKey!)"
        // planned fields intentionally left nil (this is the regression we want covered)
        context.insert(a1)

        // Instance #2: user diverged title => should keep actual title but update planned.
        let d2 = TestSupport.date(2026, 1, 12, calendar: cal)
        let a2 = Activity(title: "Custom Title", startAt: TestSupport.date(2026, 1, 12, 9, 0, calendar: cal), endAt: TestSupport.date(2026, 1, 12, 9, 30, calendar: cal))
        a2.templateId = t.id
        a2.dayKey = d2.dayKey(calendar: cal)
        a2.generatedKey = "\(t.id.uuidString)|\(a2.dayKey!)"
        a2.plannedTitle = "Old" // planned says old, actual diverged
        a2.plannedStartAt = a2.startAt
        a2.plannedEndAt = a2.endAt
        context.insert(a2)

        try context.save()

        // Change template
        t.title = "New"
        t.defaultStartMinute = 11 * 60
        t.defaultDurationMinutes = 45
        try context.save()

        let affected = try TemplatePreloader.updateExistingUpcomingInstances(
            templateId: t.id,
            from: fromDay,
            daysAhead: 10,
            context: context,
            calendar: cal
        )

        XCTAssertEqual(affected, 2)

        // Reload activities
        let acts = try context.fetch(FetchDescriptor<Activity>(sortBy: [SortDescriptor(\Activity.startAt)]))
        XCTAssertEqual(acts.count, 2)

        let r1 = acts[0]
        XCTAssertEqual(r1.plannedTitle, "New")
        XCTAssertEqual(r1.plannedStartAt, TestSupport.date(2026, 1, 11, 11, 0, calendar: cal))
        XCTAssertEqual(r1.title, "New") // updated because it matched old planned

        let r2 = acts[1]
        XCTAssertEqual(r2.plannedTitle, "New")
        XCTAssertEqual(r2.title, "Custom Title") // preserved divergence
    }
}

@MainActor
final class ProgressSummaryServiceIntegrationTests: XCTestCase {

    func test_summarizeAggregatesWeeksAndComputesStreaks() throws {
        let cal = TestSupport.utcCalendar
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        // Create 3 consecutive daily completed sessions (Jan 5, 6, 7) and one older session (Jan 1)
        func insertCompletedSession(on day: Date, completedSets: Int) {
            let started = cal.date(byAdding: .hour, value: 9, to: cal.startOfDay(for: day))!
            let ended = cal.date(byAdding: .minute, value: 60, to: started)!

            let ex = WorkoutSessionFactory.ExerciseTemplate(
                order: 0,
                exerciseId: UUID(),
                nameSnapshot: "Bench",
                notes: nil,
                sets: (0..<completedSets).map { idx in
                    .init(order: idx, targetReps: 10, targetWeight: 100, targetWeightUnit: .kg, targetRPE: nil, targetRestSeconds: nil)
                }
            )

            let s = WorkoutSessionFactory.makeSession(
                startedAt: started,
                linkedActivityId: nil,
                sourceRoutineId: nil,
                sourceRoutineNameSnapshot: nil,
                exercises: [ex],
                prefillActualsFromTargets: true
            )
            s.status = .completed
            s.endedAt = ended

            // Mark first N sets as completed
            for log in s.exercises[0].setLogs {
                log.completed = true
            }

            context.insert(s)
        }

        insertCompletedSession(on: TestSupport.date(2026, 1, 1, calendar: cal), completedSets: 1)
        insertCompletedSession(on: TestSupport.date(2026, 1, 5, calendar: cal), completedSets: 2)
        insertCompletedSession(on: TestSupport.date(2026, 1, 6, calendar: cal), completedSets: 2)
        insertCompletedSession(on: TestSupport.date(2026, 1, 7, calendar: cal), completedSets: 3)
        try context.save()

        let now = TestSupport.date(2026, 1, 7, 12, 0, calendar: cal)
        let svc = ProgressSummaryService(calendar: cal, now: { now })
        let summary = try svc.summarize(weeksBack: 2, context: context)

        // Streak: Jan 5/6/7 consecutive, and now is Jan 7 => current = 3
        XCTAssertEqual(summary.currentStreakDays, 3)
        XCTAssertEqual(summary.longestStreakDays, 3)

        // Basic aggregation sanity: there should be 2 weeks returned
        XCTAssertEqual(summary.weeks.count, 2)

        // Total workouts across both weeks in the window should include the Jan 5/6/7 sessions and likely Jan 1 depending on week window.
        let totalWorkoutsInWindow = summary.weeks.reduce(0) { $0 + $1.workoutsCompleted }
        XCTAssertTrue(totalWorkoutsInWindow >= 3)

        // Volume is reps*weight for completed sets (10*100 per set)
        let totalVolume = summary.weeks.reduce(0.0) { $0 + $1.totalVolume }
        XCTAssertTrue(totalVolume > 0)
    }
}
