import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class TemplateUpdatePlannerTests: XCTestCase {

    private let cal = TestSupport.utcCalendar

    private func makeDailyTemplate(
        title: String = "T",
        startMinute: Int = 7 * 60,
        duration: Int = 30,
        isEnabled: Bool = true,
        kind: ActivityKind = .generic,
        routineId: UUID? = nil,
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
            kind: kind,
            workoutRoutineId: routineId
        )
        context.insert(t)
        try context.save()
        return t
    }

    private func fetchActivity(on day: Date, templateId: UUID, context: ModelContext) throws -> Activity? {
        let dayStart = cal.startOfDay(for: day)
        let next = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let ds = dayStart
        let ne = next
        let tid: UUID? = templateId

        let fd = FetchDescriptor<Activity>(predicate: #Predicate<Activity> {
            $0.templateId == tid && $0.startAt >= ds && $0.startAt < ne
        })
        return try context.fetch(fd).first
    }

    func test_scopeThisAndFuture_updatesAllMaterializedInstances_previewMatchesCount() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let t = try makeDailyTemplate(startDate: cal.startOfDay(for: applyDay), context: context)

        // Materialize 3 days
        try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: context, calendar: cal)
        try TemplatePreloader.ensureDayIsPreloaded(for: cal.date(byAdding: .day, value: 1, to: applyDay)!, context: context, calendar: cal)
        try TemplatePreloader.ensureDayIsPreloaded(for: cal.date(byAdding: .day, value: 2, to: applyDay)!, context: context, calendar: cal)

        let draft = TemplateDraft(
            id: t.id,
            title: "T2",
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

        XCTAssertEqual(plan.preview.affectedCount, plan.affectedCount)
        XCTAssertEqual(plan.creates.count, 0, "Apply day already materialized; should not create.")
        XCTAssertEqual(plan.updates.count, 3, "Expected apply day + 2 future days to update.")
    }

    func test_scopeThisInstance_onlyTouchesApplyDay() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let t = try makeDailyTemplate(startDate: cal.startOfDay(for: applyDay), context: context)

        try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: context, calendar: cal)
        try TemplatePreloader.ensureDayIsPreloaded(for: cal.date(byAdding: .day, value: 1, to: applyDay)!, context: context, calendar: cal)

        let draft = TemplateDraft(
            id: t.id,
            title: "New Title",
            isEnabled: true,
            defaultStartMinute: t.defaultStartMinute,
            defaultDurationMinutes: t.defaultDurationMinutes,
            recurrence: t.recurrence,
            kind: t.kind,
            workoutRoutineId: t.workoutRoutineId
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
            overwriteActual: false,
            includeApplyDayCreate: true,
            resurrectOverridesOnApplyDay: true,
            forceApplyDay: true
        )

        XCTAssertEqual(plan.updates.count, 1)
        XCTAssertEqual(plan.creates.count, 0)
    }

    func test_overwriteActual_false_respectsUserDivergence_updatesPlanned() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let t = try makeDailyTemplate(title: "Template", startDate: cal.startOfDay(for: applyDay), context: context)
        try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: context, calendar: cal)

        // Diverge actual title from planned
        let a = try XCTUnwrap(try fetchActivity(on: applyDay, templateId: t.id, context: context))
        a.title = "Custom Title"
        try context.save()

        let draft = TemplateDraft(
            id: t.id,
            title: "Template v2",
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
            overwriteActual: false,
            includeApplyDayCreate: true,
            resurrectOverridesOnApplyDay: true,
            forceApplyDay: true
        )

        XCTAssertEqual(plan.updates.count, 1)
        let after = plan.updates[0].after
        XCTAssertEqual(after.title, "Custom Title", "Actual divergent title should remain untouched.")
        XCTAssertEqual(after.plannedTitle, "Template v2", "Planned should still update.")
    }

    func test_overwriteActual_true_overwritesUserDivergence() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let t = try makeDailyTemplate(title: "Template", startDate: cal.startOfDay(for: applyDay), context: context)
        try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: context, calendar: cal)

        let a = try XCTUnwrap(try fetchActivity(on: applyDay, templateId: t.id, context: context))
        a.title = "Custom Title"
        try context.save()

        let draft = TemplateDraft(
            id: t.id,
            title: "Template v2",
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
        XCTAssertEqual(plan.updates[0].after.title, "Template v2")
    }

    func test_detachIfNoLongerMatches_true_detachesLinkedFutureInstances() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let applyDay = TestSupport.date(2026, 1, 10, calendar: cal)
        let futureDay = cal.date(byAdding: .day, value: 1, to: applyDay)!

        let t = try makeDailyTemplate(title: "Template", startDate: cal.startOfDay(for: applyDay), context: context)
        try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: context, calendar: cal)
        try TemplatePreloader.ensureDayIsPreloaded(for: futureDay, context: context, calendar: cal)

        let disabledDraft = TemplateDraft(
            id: t.id,
            title: t.title,
            isEnabled: false,                       // no longer applies
            defaultStartMinute: t.defaultStartMinute,
            defaultDurationMinutes: t.defaultDurationMinutes,
            recurrence: t.recurrence,
            kind: t.kind,
            workoutRoutineId: t.workoutRoutineId
        )

        let planner = TemplateUpdatePlanner(calendar: cal)
        let plan = try planner.makePlan(
            templateId: t.id,
            draft: disabledDraft,
            scope: .thisAndFuture,
            applyDay: applyDay,
            context: context,
            daysAhead: 10,
            detachIfNoLongerMatches: true,
            overwriteActual: false,
            includeApplyDayCreate: false,           // focus on linked instances
            resurrectOverridesOnApplyDay: false,
            forceApplyDay: false
        )

        // We expect future instance to be detached (templateId nil, planned cleared)
        XCTAssertTrue(plan.updates.contains(where: { $0.after.templateId == nil }))
        let detached = plan.updates.first(where: { $0.after.templateId == nil })!.after
        XCTAssertNil(detached.templateId)
        XCTAssertNil(detached.plannedTitle)
        XCTAssertNil(detached.plannedStartAt)
        XCTAssertNil(detached.plannedEndAt)
    }
}
