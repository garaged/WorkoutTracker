import SwiftData
import Foundation

@MainActor
enum TemplatePreloader {
    static func ensureDayIsPreloaded(for day: Date, context: ModelContext, calendar: Calendar = .current) throws {
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

            let a = Activity(title: t.title, startAt: start, endAt: end, laneHint: 0)
            a.templateId = t.id
            a.dayKey = dayKey
            a.generatedKey = key

            // ✅ workout propagation (Template → Activity)
            applyWorkoutFields(from: t, to: a)

            a.plannedTitle = t.title
            a.plannedStartAt = start
            a.plannedEndAt = end
            a.status = .planned

            context.insert(a)
            didInsert = true
        }

        if didInsert { try context.save() }
    }
    
    @MainActor
    static func applyTemplateChange(
            templateId: UUID,
            for day: Date,
            context: ModelContext,
            calendar: Calendar = .current,
            forceForDay: Bool = false,
            resurrectIfOverridden: Bool = false,
            overwriteActual: Bool = false
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

            // For “apply to this day”, we intentionally allow forcing even if recurrence/enable doesn’t match.
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
                    // Force: overwrite "actual" fields too
                    a.title = t.title
                    a.startAt = newStart
                    a.endAt = newEnd
                } else {
                    // Safe: only overwrite "actual" if user never diverged
                    if let oldPlannedTitle, a.title == oldPlannedTitle {
                        a.title = t.title
                    }
                    if let oldPlannedStart, a.startAt == oldPlannedStart {
                        a.startAt = newStart
                    }
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
                }
                
                try context.save()
                return
            }

            // 4) Missing instance: create it (especially when resurrecting)
            let a = Activity(title: t.title, startAt: newStart, endAt: newEnd, laneHint: 0)
            a.templateId = t.id
            a.dayKey = dayKey
            a.generatedKey = key
            applyWorkoutFields(from: t, to: a)

            a.plannedTitle = t.title
            a.plannedStartAt = newStart
            a.plannedEndAt = newEnd
            a.status = .planned
            
            context.insert(a)
            try context.save()
        }
    @MainActor
    static func updateExistingUpcomingInstances(
        templateId: UUID,
        from day: Date,
        daysAhead: Int = 90,
        context: ModelContext,
        calendar: Calendar = .current,
        detachIfNoLongerMatches: Bool = true
    ) throws -> Int {
        let fromStart = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: daysAhead, to: fromStart) ?? fromStart

        // Load template once
        let templates = try context.fetch(FetchDescriptor<TemplateActivity>(
            predicate: #Predicate { $0.id == templateId }
        ))
        guard let t = templates.first else { return 0 }

        // Fetch activities linked to this template in the horizon
        let tid: UUID? = templateId
        let acts = try context.fetch(FetchDescriptor<Activity>(
            predicate: #Predicate { a in
                a.templateId == tid && a.startAt >= fromStart && a.startAt < end
            }
        ))

        var anyChanged = false
        var affectedCount = 0

        for a in acts {
            if a.status == .skipped { continue }

            let instanceDayStart = calendar.startOfDay(for: a.startAt)
            let instanceDayKey = instanceDayStart.dayKey(calendar: calendar)
            let key = "\(templateId.uuidString)|\(instanceDayKey)"

            // Respect overrides (skip/delete)
            let overrides = try context.fetch(FetchDescriptor<TemplateInstanceOverride>(
                predicate: #Predicate { $0.key == key }
            ))
            if !overrides.isEmpty { continue }

            // Snapshot before (for accurate counting)
            struct ActivitySnapshot: Equatable {
                let title: String
                let startAt: Date
                let endAt: Date?

                let templateId: UUID?
                let dayKey: String?
                let generatedKey: String?

                let plannedTitle: String?
                let plannedStartAt: Date?
                let plannedEndAt: Date?

                let kindRaw: String
                let workoutRoutineId: UUID?
                let workoutSessionId: UUID?
            }


            func snap(_ a: Activity) -> ActivitySnapshot {
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

                    kindRaw: a.kindRaw,
                    workoutRoutineId: a.workoutRoutineId,
                    workoutSessionId: a.workoutSessionId
                )
            }

            let before = snap(a)

            // If template no longer applies, optionally detach old instances
            if (!t.isEnabled || !t.recurrence.matches(day: instanceDayStart, calendar: calendar)) {
                if detachIfNoLongerMatches {
                    a.templateId = nil
                    a.generatedKey = nil
                    a.dayKey = instanceDayKey
                    a.plannedTitle = nil
                    a.plannedStartAt = nil
                    a.plannedEndAt = nil
                    if a.status == .planned && a.workoutSessionId == nil {
                        a.kind = .generic
                        a.workoutRoutineId = nil
                    }
                } else {
                    continue
                }
            } else {
                let newStart = calendar.date(byAdding: .minute, value: t.defaultStartMinute, to: instanceDayStart) ?? instanceDayStart
                let newEnd = calendar.date(byAdding: .minute, value: t.defaultDurationMinutes, to: newStart)

                // Repair keys for older rows
                a.dayKey = instanceDayKey
                a.generatedKey = key

                // NIL fallback makes older instances update consistently
                let oldPlannedTitle = a.plannedTitle ?? a.title
                let oldPlannedStart = a.plannedStartAt ?? a.startAt
                let oldPlannedEnd = a.plannedEndAt ?? a.endAt

                // Always update planned fields
                a.plannedTitle = t.title
                a.plannedStartAt = newStart
                a.plannedEndAt = newEnd
                
                let safeToSyncWorkout = (a.status == .planned && a.workoutSessionId == nil)
                if safeToSyncWorkout {
                    applyWorkoutFields(from: t, to: a)
                }

                // Only update actual if user didn't diverge
                if a.title == oldPlannedTitle { a.title = t.title }
                if a.startAt == oldPlannedStart { a.startAt = newStart }

                if let oldPlannedEnd {
                    if a.endAt == oldPlannedEnd { a.endAt = newEnd }
                } else {
                    if a.endAt == nil { a.endAt = newEnd }
                }
            }

            let after = snap(a)

            if before != after {
                affectedCount += 1
                anyChanged = true
            }
        }

        if anyChanged {
            try context.save()
        }

        return affectedCount
    }
    
    private static func applyWorkoutFields(from template: TemplateActivity, to activity: Activity) {
        activity.kind = template.kind
        activity.workoutRoutineId = (template.kind == .workout) ? template.workoutRoutineId : nil
    }

}
