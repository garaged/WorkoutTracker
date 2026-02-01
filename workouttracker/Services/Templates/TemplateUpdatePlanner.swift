import Foundation
import SwiftData

@MainActor
struct TemplateUpdatePlanner {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func makePlan(
        templateId: UUID,
        draft: TemplateDraft,
        scope: UpdateScope,
        applyDay: Date,
        context: ModelContext,
        daysAhead: Int = 120,
        detachIfNoLongerMatches: Bool = true,
        overwriteActual: Bool = false,
        includeApplyDayCreate: Bool = true,
        resurrectOverridesOnApplyDay: Bool = true,
        forceApplyDay: Bool = true
    ) throws -> TemplateUpdatePlan {

        let applyDayStart = calendar.startOfDay(for: applyDay)
        let applyDayKey = applyDayStart.dayKey(calendar: calendar)
        let applyKey = "\(templateId.uuidString)|\(applyDayKey)"

        // ---- Overrides set (so future updates skip overrides)
        let overrideKeys = try fetchOverrideKeys(
            templateId: templateId,
            scope: scope,
            applyDayStart: applyDayStart,
            daysAhead: daysAhead,
            context: context
        )

        // ---- Existing activities window for future/all
        let candidateActivities: [Activity] = try fetchCandidateActivities(
            templateId: templateId,
            scope: scope,
            applyDayStart: applyDayStart,
            daysAhead: daysAhead,
            context: context
        )

        // ---- Apply-day activity is fetched by generatedKey (matches your current applyTemplateChange)
        let applyDayExisting = try fetchActivityByGeneratedKey(applyKey, context: context).first

        var overrideKeysToDelete: [String] = []
        if resurrectOverridesOnApplyDay {
            let applyOverrides = try fetchOverridesByKey(applyKey, context: context)
            if !applyOverrides.isEmpty {
                overrideKeysToDelete.append(applyKey)
            }
        }

        var updates: [PlannedActivityUpdate] = []
        var creates: [PlannedActivityCreate] = []
        var beforeSnapshots: [UUID: ActivitySnapshot] = [:]
        var createdGeneratedKeys: [String] = []

        // MARK: - plan applyDay (if scope includes it)
        let scopeIncludesApplyDay = (scope == .thisInstance || scope == .thisAndFuture || scope == .allInstances)

        if scopeIncludesApplyDay {
            // If override exists and we are NOT resurrecting, do nothing.
            if overrideKeys.contains(applyKey) && !resurrectOverridesOnApplyDay {
                // no-op
            } else {
                if let a = applyDayExisting {
                    let before = snap(a)
                    let after = computeAfterForApplyDay(
                        activity: a,
                        draft: draft,
                        dayStart: applyDayStart,
                        dayKey: applyDayKey,
                        generatedKey: applyKey,
                        overwriteActual: overwriteActual
                    )
                    if before != after {
                        beforeSnapshots[a.id] = before
                        updates.append(.init(activityId: a.id, after: after))
                    }
                } else if includeApplyDayCreate && shouldApplyOnApplyDay(draft: draft, dayStart: applyDayStart, forceApplyDay: forceApplyDay) {
                    let start = calendar.date(byAdding: .minute, value: draft.defaultStartMinute, to: applyDayStart) ?? applyDayStart
                    let end = calendar.date(byAdding: .minute, value: draft.defaultDurationMinutes, to: start)

                    let kind = draft.kind
                    let routineId = (kind == .workout) ? draft.workoutRoutineId : nil

                    creates.append(.init(
                        generatedKey: applyKey,
                        dayKey: applyDayKey,
                        title: draft.title,
                        startAt: start,
                        endAt: end,
                        kind: kind,
                        workoutRoutineId: routineId,
                        templateId: templateId,
                        plannedTitle: draft.title,
                        plannedStartAt: start,
                        plannedEndAt: end
                    ))
                    createdGeneratedKeys.append(applyKey)
                }
            }
        }

        // MARK: - plan future/all updates (based on templateId link)
        for a in candidateActivities {
            if a.status == .skipped { continue }

            let instanceDayStart = calendar.startOfDay(for: a.startAt)
            let instanceDayKey = instanceDayStart.dayKey(calendar: calendar)
            let key = "\(templateId.uuidString)|\(instanceDayKey)"

            // Apply-day is already handled above (generatedKey based)
            if instanceDayKey == applyDayKey && scope != .allInstances {
                // In `.thisAndFuture`, the window fetch includes applyDay rows; skip them here to avoid double work.
                continue
            }

            // Respect overrides (skip)
            if overrideKeys.contains(key) { continue }

            let before = snap(a)
            let after = computeAfterForLinkedInstance(
                activity: a,
                draft: draft,
                instanceDayStart: instanceDayStart,
                instanceDayKey: instanceDayKey,
                generatedKey: key,
                detachIfNoLongerMatches: detachIfNoLongerMatches,
                overwriteActual: overwriteActual
            )

            if before != after {
                beforeSnapshots[a.id] = before
                updates.append(.init(activityId: a.id, after: after))
            }
        }

        // Stable ordering: sort by after.startAt then id
        updates.sort {
            if $0.after.startAt != $1.after.startAt { return $0.after.startAt < $1.after.startAt }
            return $0.activityId.uuidString < $1.activityId.uuidString
        }

        let sampleDates = (updates.prefix(3).map { $0.after.startAt } + creates.prefix(3).map { $0.startAt })
            .prefix(3)

        let preview = TemplateUpdatePreview(
            affectedCount: updates.count + creates.count,
            sampleStartDates: Array(sampleDates)
        )

        return TemplateUpdatePlan(
            templateId: templateId,
            scope: scope,
            applyDay: applyDayStart,
            updates: updates,
            creates: creates,
            overrideKeysToDelete: overrideKeysToDelete,
            beforeSnapshots: beforeSnapshots,
            createdGeneratedKeys: createdGeneratedKeys,
            preview: preview
        )
    }

    // MARK: - Candidate fetches

    private func fetchCandidateActivities(
        templateId: UUID,
        scope: UpdateScope,
        applyDayStart: Date,
        daysAhead: Int,
        context: ModelContext
    ) throws -> [Activity] {
        let tid: UUID? = templateId

        switch scope {
        case .thisInstance:
            return []

        case .thisAndFuture:
            let end = calendar.date(byAdding: .day, value: daysAhead, to: applyDayStart) ?? applyDayStart
            return try context.fetch(FetchDescriptor<Activity>(
                predicate: #Predicate { a in
                    a.templateId == tid && a.startAt >= applyDayStart && a.startAt < end
                }
            ))

        case .allInstances:
            return try context.fetch(FetchDescriptor<Activity>(
                predicate: #Predicate { a in
                    a.templateId == tid
                }
            ))
        }
    }

    private func fetchOverrideKeys(
        templateId: UUID,
        scope: UpdateScope,
        applyDayStart: Date,
        daysAhead: Int,
        context: ModelContext
    ) throws -> Set<String> {
        switch scope {
        case .thisInstance:
            // handled directly via key fetch in makePlan
            return []

        case .thisAndFuture:
            let fromKey = applyDayStart.dayKey(calendar: calendar)
            let endDay = calendar.date(byAdding: .day, value: daysAhead, to: applyDayStart) ?? applyDayStart
            let toKey = endDay.dayKey(calendar: calendar)

            let ovs = try context.fetch(FetchDescriptor<TemplateInstanceOverride>(
                predicate: #Predicate { ov in
                    ov.dayKey >= fromKey && ov.dayKey < toKey
                }
            ))

            return Set(ovs.map(\.key).filter { $0.hasPrefix("\(templateId.uuidString)|") })

        case .allInstances:
            // small dataset assumption; fetch all then filter
            let ovs = try context.fetch(FetchDescriptor<TemplateInstanceOverride>())
            return Set(ovs.map(\.key).filter { $0.hasPrefix("\(templateId.uuidString)|") })
        }
    }

    private func fetchActivityByGeneratedKey(_ key: String, context: ModelContext) throws -> [Activity] {
        try context.fetch(FetchDescriptor<Activity>(
            predicate: #Predicate { $0.generatedKey == key }
        ))
    }

    private func fetchOverridesByKey(_ key: String, context: ModelContext) throws -> [TemplateInstanceOverride] {
        try context.fetch(FetchDescriptor<TemplateInstanceOverride>(
            predicate: #Predicate { $0.key == key }
        ))
    }

    // MARK: - After-state computation (mirrors your existing rules)

    private func shouldApplyOnApplyDay(draft: TemplateDraft, dayStart: Date, forceApplyDay: Bool) -> Bool {
        if forceApplyDay { return true }
        guard draft.isEnabled else { return false }
        return draft.recurrence.matches(day: dayStart, calendar: calendar)
    }

    private func computeAfterForApplyDay(
        activity a: Activity,
        draft: TemplateDraft,
        dayStart: Date,
        dayKey: String,
        generatedKey: String,
        overwriteActual: Bool
    ) -> ActivitySnapshot {
        let newStart = calendar.date(byAdding: .minute, value: draft.defaultStartMinute, to: dayStart) ?? dayStart
        let newEnd = calendar.date(byAdding: .minute, value: draft.defaultDurationMinutes, to: newStart)

        // NIL fallback makes older instances update consistently (same as your bulk updater)
        let oldPlannedTitle = a.plannedTitle ?? a.title
        let oldPlannedStart = a.plannedStartAt ?? a.startAt
        let oldPlannedEnd = a.plannedEndAt ?? a.endAt

        var title = a.title
        var startAt = a.startAt
        var endAt = a.endAt

        // Always update planned fields
        let plannedTitle = draft.title
        let plannedStartAt = newStart
        let plannedEndAt = newEnd

        if overwriteActual {
            title = draft.title
            startAt = newStart
            endAt = newEnd
        } else {
            if title == oldPlannedTitle { title = draft.title }
            if startAt == oldPlannedStart { startAt = newStart }
            if let oldPlannedEnd {
                if endAt == oldPlannedEnd { endAt = newEnd }
            } else {
                if endAt == nil { endAt = newEnd }
            }
        }

        // Workout linkage syncing: overwriteActual OR safe planned+no session
        let safeToSyncWorkout = overwriteActual || (a.status == .planned && a.workoutSessionId == nil)

        let kind: ActivityKind
        let routineId: UUID?

        if safeToSyncWorkout {
            kind = draft.kind
            routineId = (draft.kind == .workout) ? draft.workoutRoutineId : nil
        } else {
            // normalize invariants only
            kind = a.kind
            routineId = (a.kind == .workout) ? a.workoutRoutineId : nil
        }

        return ActivitySnapshot(
            title: title,
            startAt: startAt,
            endAt: endAt,
            templateId: draft.id,
            dayKey: dayKey,
            generatedKey: generatedKey,
            plannedTitle: plannedTitle,
            plannedStartAt: plannedStartAt,
            plannedEndAt: plannedEndAt,
            kind: (kind == .workout ? .workout : .generic),
            workoutRoutineId: (kind == .workout ? routineId : nil),
            workoutSessionId: a.workoutSessionId,
            status: a.status
        )
    }

    private func computeAfterForLinkedInstance(
        activity a: Activity,
        draft: TemplateDraft,
        instanceDayStart: Date,
        instanceDayKey: String,
        generatedKey: String,
        detachIfNoLongerMatches: Bool,
        overwriteActual: Bool
    ) -> ActivitySnapshot {

        // If template no longer applies, detach (mirrors your old bulk update)
        let stillApplies = draft.isEnabled && draft.recurrence.matches(day: instanceDayStart, calendar: calendar)
        if !stillApplies {
            if detachIfNoLongerMatches {
                var kind = a.kind
                var routineId = a.workoutRoutineId

                if a.status == .planned && a.workoutSessionId == nil {
                    kind = .generic
                    routineId = nil
                }

                return ActivitySnapshot(
                    title: a.title,
                    startAt: a.startAt,
                    endAt: a.endAt,
                    templateId: nil,
                    dayKey: instanceDayKey,
                    generatedKey: nil,
                    plannedTitle: nil,
                    plannedStartAt: nil,
                    plannedEndAt: nil,
                    kind: kind,
                    workoutRoutineId: (kind == .workout ? routineId : nil),
                    workoutSessionId: a.workoutSessionId,
                    status: a.status
                )
            } else {
                return snap(a) // no-op
            }
        }

        // Otherwise update planned + maybe actual (divergence-aware)
        let newStart = calendar.date(byAdding: .minute, value: draft.defaultStartMinute, to: instanceDayStart) ?? instanceDayStart
        let newEnd = calendar.date(byAdding: .minute, value: draft.defaultDurationMinutes, to: newStart)

        let oldPlannedTitle = a.plannedTitle ?? a.title
        let oldPlannedStart = a.plannedStartAt ?? a.startAt
        let oldPlannedEnd = a.plannedEndAt ?? a.endAt

        var title = a.title
        var startAt = a.startAt
        var endAt = a.endAt

        // planned always updated
        let plannedTitle = draft.title
        let plannedStartAt = newStart
        let plannedEndAt = newEnd

        if overwriteActual {
            title = draft.title
            startAt = newStart
            endAt = newEnd
        } else {
            if title == oldPlannedTitle { title = draft.title }
            if startAt == oldPlannedStart { startAt = newStart }

            if let oldPlannedEnd {
                if endAt == oldPlannedEnd { endAt = newEnd }
            } else {
                if endAt == nil { endAt = newEnd }
            }
        }

        // Workout linkage syncing (bulk rule + overwriteActual)
        let safeToSyncWorkout = overwriteActual || (a.status == .planned && a.workoutSessionId == nil)

        let kind: ActivityKind
        let routineId: UUID?

        if safeToSyncWorkout {
            kind = draft.kind
            routineId = (draft.kind == .workout) ? draft.workoutRoutineId : nil
        } else {
            kind = a.kind
            routineId = (a.kind == .workout) ? a.workoutRoutineId : nil
        }

        return ActivitySnapshot(
            title: title,
            startAt: startAt,
            endAt: endAt,
            templateId: draft.id,
            dayKey: instanceDayKey,           // repair keys
            generatedKey: generatedKey,       // repair keys
            plannedTitle: plannedTitle,
            plannedStartAt: plannedStartAt,
            plannedEndAt: plannedEndAt,
            kind: (kind == .workout ? .workout : .generic),
            workoutRoutineId: (kind == .workout ? routineId : nil),
            workoutSessionId: a.workoutSessionId,
            status: a.status
        )
    }

    private func snap(_ a: Activity) -> ActivitySnapshot {
        ActivitySnapshot(
            title: a.title,
            startAt: a.startAt,
            endAt: a.endAt,
            templateId: a.templateId,
            dayKey: a.dayKey,
            generatedKey: a.generatedKey,
            plannedTitle: a.plannedTitle,
            plannedStartAt: a.plannedStartAt,
            plannedEndAt: a.plannedEndAt,
            kind: a.kind,
            workoutRoutineId: a.workoutRoutineId,
            workoutSessionId: a.workoutSessionId,
            status: a.status
        )
    }
}
