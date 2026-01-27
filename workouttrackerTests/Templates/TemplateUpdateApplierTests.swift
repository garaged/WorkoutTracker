import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class TemplateUpdateApplierTests: XCTestCase {

    private let cal = TestSupport.utcCalendar

    private func makeDailyTemplate(
        title: String = "T",
        startMinute: Int = 7 * 60,
        duration: Int = 30,
        startDate: Date,
        context: ModelContext
    ) throws -> TemplateActivity {
        let rule = RecurrenceRule(kind: .daily, startDate: startDate, endDate: nil, interval: 1, weekdays: [])
        let t = TemplateActivity(
            title: title,
            defaultStartMinute: startMinute,
            defaultDurationMinutes: duration,
            isEnabled: true,
            recurrence: rule,
            kind: .generic,
            workoutRoutineId: nil
        )
        context.insert(t)
        try context.save()
        return t
    }

    private func fetchActivitiesBetween(_ start: Date, _ end: Date, context: ModelContext) throws -> [Activity] {
        let s = start
        let e = end
        let fd = FetchDescriptor<Activity>(predicate: #Predicate<Activity> { $0.startAt >= s && $0.startAt < e })
        return try context.fetch(fd)
    }

    func test_apply_updatesExisting_and_createsMissingApplyDay() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let futureDay = cal.date(byAdding: .day, value: 1, to: applyDay)!

        let t = try makeDailyTemplate(startDate: cal.startOfDay(for: applyDay), context: context)

        // Materialize ONLY the future day; apply day is intentionally missing
        try TemplatePreloader.ensureDayIsPreloaded(for: futureDay, context: context, calendar: cal)

        let draft = TemplateDraft(
            id: t.id,
            title: "New Title",
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
            overwriteActual: false,
            includeApplyDayCreate: true,
            resurrectOverridesOnApplyDay: true,
            forceApplyDay: true
        )

        XCTAssertEqual(plan.creates.count, 1, "Apply day missing -> should be created.")
        XCTAssertGreaterThanOrEqual(plan.updates.count, 1, "Future day exists -> should update.")

        let applier = TemplateUpdateApplier()
        try applier.apply(plan: plan, context: context)
        try context.save()

        // Assert apply day now exists with the new title
        let dayStart = cal.startOfDay(for: applyDay)
        let nextDayStart = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let dayActs = try fetchActivitiesBetween(dayStart, nextDayStart, context: context)

        XCTAssertTrue(dayActs.contains(where: { $0.title == "New Title" }),
                      "Expected created apply-day activity with updated title.")

        // Assert future day activity updated too
        let futureStart = cal.startOfDay(for: futureDay)
        let futureEnd = cal.date(byAdding: .day, value: 1, to: futureStart)!
        let futureActs = try fetchActivitiesBetween(futureStart, futureEnd, context: context)

        XCTAssertTrue(futureActs.contains(where: { $0.title == "New Title" }),
                      "Expected updated future activity title.")
    }

    func test_apply_rollsBack_whenMidApplyFails() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let t = try makeDailyTemplate(title: "Original", startDate: cal.startOfDay(for: applyDay), context: context)

        // Materialize apply day so we have an existing activity
        try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: context, calendar: cal)

        // Build a plan that would update the existing activity…
        let draft = TemplateDraft(
            id: t.id,
            title: "Updated",
            isEnabled: true,
            defaultStartMinute: t.defaultStartMinute,
            defaultDurationMinutes: t.defaultDurationMinutes,
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

        XCTAssertEqual(plan.updates.count, 1)

        // …then corrupt it by adding a missing activity update to force failure after one mutation.
        var badUpdates = plan.updates
        badUpdates.append(.init(activityId: UUID(), after: plan.updates[0].after))

        let badPlan = TemplateUpdatePlan(
            templateId: plan.templateId,
            scope: plan.scope,
            applyDay: plan.applyDay,
            updates: badUpdates,
            creates: plan.creates,
            overrideKeysToDelete: plan.overrideKeysToDelete,
            beforeSnapshots: plan.beforeSnapshots,
            createdGeneratedKeys: plan.createdGeneratedKeys,
            preview: plan.preview
        )

        let applier = TemplateUpdateApplier()
        XCTAssertThrowsError(try applier.apply(plan: badPlan, context: context))

        // The existing activity should be rolled back to original title
        let dayStart = cal.startOfDay(for: applyDay)
        let next = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let acts = try fetchActivitiesBetween(dayStart, next, context: context)

        XCTAssertTrue(acts.contains(where: { $0.title == "Original" }),
                      "Rollback should restore the original title after failure.")
    }
}
