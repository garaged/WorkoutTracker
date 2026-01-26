import SwiftData
import Foundation

@MainActor
enum TemplatePreloader {

    // MARK: - Public API

    static func ensureDayIsPreloaded(
        for day: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let dayStart = calendar.startOfDay(for: day)
        let dayKey = day.dayKey(calendar: calendar)

        let templates = try context.fetch(FetchDescriptor<TemplateActivity>(
            predicate: #Predicate { $0.isEnabled == true }
        ))

        let overrides = try context.fetch(FetchDescriptor<TemplateInstanceOverride>(
            predicate: #Predicate { $0.dayKey == dayKey }
        ))
        let overrideKeys = Set(overrides.map(\.key))

        let existing = try context.fetch(FetchDescriptor<Activity>(
            predicate: #Predicate { $0.dayKey == dayKey }
        ))
        let existingKeys = Set(existing.compactMap(\.generatedKey))

        var didInsert = false

        for t in templates {
            guard t.recurrence.matches(day: dayStart, calendar: calendar) else { continue }

            let key = "\(t.id.uuidString)|\(dayKey)"
            if overrideKeys.contains(key) { continue }
            if existingKeys.contains(key) { continue }

            let start = calendar.date(byAdding: .minute, value: t.defaultStartMinute, to: dayStart) ?? dayStart
            let end = calendar.date(byAdding: .minute, value: t.defaultDurationMinutes, to: start)

            let a = Activity(
                title: t.title,
                startAt: start,
                endAt: end,
                laneHint: 0,
                kind: t.kind,
                workoutRoutineId: (t.kind == .workout ? t.workoutRoutineId : nil)
            )

            a.templateId = t.id
            a.dayKey = dayKey
            a.generatedKey = key

            // Planned snapshot
            a.plannedTitle = t.title
            a.plannedStartAt = start
            a.plannedEndAt = end
            a.status = .planned

            // If template is not workout, ensure linkage is cleared
            normalizeWorkoutLinkageIfNeeded(activity: a)

            context.insert(a)
            didInsert = true
        }

        if didInsert { try context.save() }
    }

    static func applyTemplateChange(
        templateId: UUID,
        for day: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        forceForDay: Bool = false,
        resurrectIfOverridden: Bool = false,
        overwriteActual: Bool = false,
        saveChanges: Bool = true
    ) throws {
        let dayStart = calendar.startOfDay(for: day)
        let dayKey = day.dayKey(calendar: calendar)
        let key = "\(templateId.uuidString)|\(dayKey)"

        // 1) Overrides: normally block regeneration; but "resurrect" removes them.
        let overrides = try context.fetch(FetchDescriptor<TemplateInstanceOverride>(
            predicate: #Predicate { $0.key == key }
        ))

        if !overrides.isEmpty {
            if resurrectIfOverridden {
                for ov in overrides { context.delete(ov) }
            } else {
                return
            }
        }

        // 2) Load template
        let templates = try context.fetch(FetchDescriptor<TemplateActivity>(
            predicate: #Predicate { $0.id == templateId }
        ))
        guard let t = templates.first else { return }

        // For “apply to this day”, allow forcing even if recurrence/enable doesn’t match.
        if !forceForDay {
            guard t.isEnabled else { return }
            guard t.recurrence.matches(day: dayStart, calendar: calendar) else { return }
        }

        let newStart = calendar.date(byAdding: .minute, value: t.defaultStartMinute, to: dayStart) ?? dayStart
        let newEnd = calendar.date(byAdding: .minute, value: t.defaultDurationMinutes, to: newStart)

        // 3) Find existing instance for this day
        let existing = try context.fetch(FetchDescriptor<Activity>(
            predicate: #Predicate { $0.generatedKey == key }
        ))

        if let a = existing.first {
            let oldPlannedTitle = a.plannedTitle
            let oldPlannedStart = a.plannedStartAt
            let oldPlannedEnd = a.plannedEndAt

            // Always update planned fields
            a.plannedTitle = t.title
            a.plannedStartAt = newStart
            a.plannedEndAt = newEnd

            if overwriteActual {
                a.title = t.title
                a.startAt = newStart
                a.endAt = newEnd
            } else {
                // Only overwrite "actual" if user never diverged
                if let oldPlannedTitle, a.title == oldPlannedTitle { a.title = t.title }
                if let oldPlannedStart, a.startAt == oldPlannedStart { a.startAt = newStart }

                if let oldPlannedEnd {
                    if a.endAt == oldPlannedEnd { a.endAt = newEnd }
                } else {
                    if a.endAt == nil { a.endAt = newEnd }
                }
            }

            a.templateId = t.id
            a.dayKey = dayKey
            a.generatedKey = key

            // ✅ keep workout linkage synced, but never rewrite started sessions
            let safeToSyncWorkout = overwriteActual || (a.status == .planned && a.workoutSessionId == nil)
            if safeToSyncWorkout {
                applyWorkoutFields(from: t, to: a)
            } else {
                // Still ensure invariants hold if kind is not workout
                normalizeWorkoutLinkageIfNeeded(activity: a)
            }

            if saveChanges { try context.save() }
            return
        }

        // 4) Missing instance: create it (especially when resurrecting)
        let a = Activity(
            title: t.title,
            startAt: newStart,
            endAt: newEnd,
            laneHint: 0,
            kind: t.kind,
            workoutRoutineId: (t.kind == .workout ? t.workoutRoutineId : nil)
        )
        a.templateId = t.id
        a.dayKey = dayKey
        a.generatedKey = key

        a.plannedTitle = t.title
        a.plannedStartAt = newStart
        a.plannedEndAt = newEnd
        a.status = .planned

        normalizeWorkoutLinkageIfNeeded(activity: a)

        context.insert(a)
        if saveChanges { try context.save() }
    }

    /// Now a thin wrapper around Planner/Applier (keeps legacy call sites working).
    static func updateExistingUpcomingInstances(
        templateId: UUID,
        from day: Date,
        daysAhead: Int = 90,
        context: ModelContext,
        calendar: Calendar = .current,
        detachIfNoLongerMatches: Bool = true
    ) throws -> Int {
        let fromStart = calendar.startOfDay(for: day)

        // Load template once
        let templates = try context.fetch(FetchDescriptor<TemplateActivity>(
            predicate: #Predicate { $0.id == templateId }
        ))
        guard let t = templates.first else { return 0 }

        let draft = TemplateDraft(
            id: t.id,
            title: t.title,
            isEnabled: t.isEnabled,
            defaultStartMinute: t.defaultStartMinute,
            defaultDurationMinutes: t.defaultDurationMinutes,
            recurrence: t.recurrence,
            kind: t.kind,
            workoutRoutineId: t.workoutRoutineId
        )

        let planner = TemplateUpdatePlanner(calendar: calendar)
        let plan = try planner.makePlan(
            templateId: templateId,
            draft: draft,
            scope: .thisAndFuture,
            applyDay: fromStart,
            context: context,
            daysAhead: daysAhead,
            detachIfNoLongerMatches: detachIfNoLongerMatches,
            overwriteActual: false,
            includeApplyDayCreate: false,            // legacy bulk updater did NOT create
            resurrectOverridesOnApplyDay: false,     // legacy bulk updater never resurrected
            forceApplyDay: false
        )

        if plan.affectedCount == 0 { return 0 }

        let applier = TemplateUpdateApplier()
        try applier.apply(plan: plan, context: context)
        try context.save()

        return plan.affectedCount
    }

    // MARK: - Helpers

    private static func applyWorkoutFields(from template: TemplateActivity, to activity: Activity) {
        activity.kind = template.kind
        activity.workoutRoutineId = (template.kind == .workout) ? template.workoutRoutineId : nil

        // Invariants: if not workout, clear
        normalizeWorkoutLinkageIfNeeded(activity: activity)
    }

    private static func normalizeWorkoutLinkageIfNeeded(activity: Activity) {
        if activity.kind != .workout {
            activity.workoutRoutineId = nil
            // never force-clear workoutSessionId here (that represents history)
        }
    }
}
