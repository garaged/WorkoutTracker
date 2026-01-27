import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class TemplateUpdateOverrideBehaviorTests: XCTestCase {

    private let cal = TestSupport.utcCalendar

    private func makeDailyTemplate(
        title: String = "Old",
        startMinute: Int = 7 * 60,
        duration: Int = 30,
        isEnabled: Bool = true,
        startDate: Date,
        context: ModelContext
    ) throws -> TemplateActivity {
        let rule = RecurrenceRule(kind: .daily, startDate: startDate, endDate: nil, interval: 1, weekdays: [])
        let t = TemplateActivity(
            title: title,
            defaultStartMinute: startMinute,
            defaultDurationMinutes: duration,
            isEnabled: isEnabled,
            recurrence: rule,
            kind: .generic,
            workoutRoutineId: nil
        )
        context.insert(t)
        try context.save()
        return t
    }

    private func insertOverride(
        templateId: UUID,
        day: Date,
        action: TemplateOverrideAction,
        context: ModelContext
    ) throws {
        let dayKey = day.dayKey(calendar: cal)
        let ov = TemplateInstanceOverride(templateId: templateId, dayKey: dayKey, action: action)
        context.insert(ov)
        try context.save()
    }

    private func fetchOverrideCount(forKey key: String, context: ModelContext) throws -> Int {
        let k = key
        let ovs = try context.fetch(FetchDescriptor<TemplateInstanceOverride>(
            predicate: #Predicate<TemplateInstanceOverride> { $0.key == k }
        ))
        return ovs.count
    }

    private func fetchActivityByGeneratedKey(_ key: String, context: ModelContext) throws -> Activity? {
        let k: String? = key
        return try context.fetch(FetchDescriptor<Activity>(
            predicate: #Predicate<Activity> { $0.generatedKey == k }
        )).first
    }

    func test_planner_skipsOverriddenFutureDay_and_applierDoesNotChangeIt() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let day1 = cal.date(byAdding: .day, value: 1, to: applyDay)!
        let day2 = cal.date(byAdding: .day, value: 2, to: applyDay)!

        let t = try makeDailyTemplate(startDate: cal.startOfDay(for: applyDay), context: context)

        // Materialize 3 days
        try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: context, calendar: cal)
        try TemplatePreloader.ensureDayIsPreloaded(for: day1, context: context, calendar: cal)
        try TemplatePreloader.ensureDayIsPreloaded(for: day2, context: context, calendar: cal)

        // User override on day1 (skip/delete) should block template updates for that day.
        try insertOverride(templateId: t.id, day: day1, action: .skippedToday, context: context)

        let draft = TemplateDraft(
            id: t.id,
            title: "New",
            isEnabled: true,
            defaultStartMinute: 8 * 60,
            defaultDurationMinutes: 45,
            recurrence: t.recurrence,
            kind: .generic,
            workoutRoutineId: nil
        )

        let planner = TemplateUpdatePlanner(calendar: cal)
        let plan = try planner.makePlan(
            templateId: t.id,
            draft: draft,
            scope: .thisAndFuture,
            applyDay: applyDay,
            context: context,
            daysAhead: 10,
            detachIfNoLongerMatches: true,
            overwriteActual: true,
            includeApplyDayCreate: true,
            resurrectOverridesOnApplyDay: false,
            forceApplyDay: true
        )

        // Expect applyDay + day2 updated, but day1 skipped due to override.
        let day1Key = day1.dayKey(calendar: cal)
        XCTAssertFalse(plan.updates.contains(where: { $0.after.dayKey == day1Key }),
                       "Planner must skip overridden day1 instance.")

        let applier = TemplateUpdateApplier()
        try applier.apply(plan: plan, context: context)
        try context.save()

        // Verify day1 activity did not change (still old planned/title)
        let key1 = "\(t.id.uuidString)|\(day1Key)"
        let a1 = try XCTUnwrap(try fetchActivityByGeneratedKey(key1, context: context))
        XCTAssertEqual(a1.title, "Old")
        XCTAssertEqual(a1.plannedTitle, "Old")
    }

    func test_resurrectApplyDay_override_isDeleted_and_activityIsCreated() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let t = try makeDailyTemplate(startDate: cal.startOfDay(for: applyDay), context: context)

        // Insert override for applyDay BEFORE preload, so the apply-day activity does not exist.
        let applyDayKey = applyDay.dayKey(calendar: cal)
        let applyKey = "\(t.id.uuidString)|\(applyDayKey)"
        try insertOverride(templateId: t.id, day: applyDay, action: .deletedToday, context: context)

        XCTAssertEqual(try fetchOverrideCount(forKey: applyKey, context: context), 1)
        XCTAssertNil(try fetchActivityByGeneratedKey(applyKey, context: context),
                     "Apply-day activity should be absent because override exists.")

        let draft = TemplateDraft(
            id: t.id,
            title: "New",
            isEnabled: true,
            defaultStartMinute: 9 * 60,
            defaultDurationMinutes: 20,
            recurrence: t.recurrence,
            kind: .generic,
            workoutRoutineId: nil
        )

        let planner = TemplateUpdatePlanner(calendar: cal)
        let plan = try planner.makePlan(
            templateId: t.id,
            draft: draft,
            scope: .thisInstance,
            applyDay: applyDay,
            context: context,
            daysAhead: 10,
            detachIfNoLongerMatches: true,
            overwriteActual: true,
            includeApplyDayCreate: true,
            resurrectOverridesOnApplyDay: true,
            forceApplyDay: true
        )

        XCTAssertTrue(plan.overrideKeysToDelete.contains(applyKey),
                      "Resurrect should plan to delete the apply-day override.")
        XCTAssertEqual(plan.creates.count, 1, "Resurrect with missing apply-day row should create it.")

        let applier = TemplateUpdateApplier()
        try applier.apply(plan: plan, context: context)
        try context.save()

        // Override should be removed and activity should exist.
        XCTAssertEqual(try fetchOverrideCount(forKey: applyKey, context: context), 0,
                       "Applier must delete resurrected override.")
        let a = try XCTUnwrap(try fetchActivityByGeneratedKey(applyKey, context: context))
        XCTAssertEqual(a.title, "New")
        XCTAssertEqual(a.plannedTitle, "New")
    }
}
