// workouttracker/Services/Programs/ProgramSchedulingService.swift
import Foundation
import SwiftData

@MainActor
enum ProgramSchedulingService {

    enum ConflictStrategy: String, CaseIterable, Identifiable {
        case skipConflicts
        case replaceInSlot
        case allowOverlap

        var id: String { rawValue }

        var label: String {
            switch self {
            case .skipConflicts: return "Skip conflicts"
            case .replaceInSlot: return "Replace in time slot"
            case .allowOverlap:  return "Allow overlaps"
            }
        }
    }

    struct Preview: Sendable {
        var totalActivities: Int
        var workoutActivities: Int
        var trainingDays: Int
        var dateRange: ClosedRange<Date>?
        var missingRoutineSlugs: [String]

        var isSchedulable: Bool { missingRoutineSlugs.isEmpty }
    }

    struct Result: Sendable {
        var created: Int
        var skipped: Int
        var deleted: Int
    }

    enum ScheduleError: LocalizedError {
        case missingRoutines([String])

        var errorDescription: String? {
            switch self {
            case .missingRoutines(let slugs):
                return "Cannot schedule. Missing required routines:\n" + slugs.joined(separator: "\n")
            }
        }
    }

    struct Options: Sendable {
        var startDate: Date
        var startTime: Date
        var includeRestDays: Bool
        var conflictStrategy: ConflictStrategy

        init(
            startDate: Date,
            startTime: Date,
            includeRestDays: Bool = true,
            conflictStrategy: ConflictStrategy = .skipConflicts
        ) {
            self.startDate = startDate
            self.startTime = startTime
            self.includeRestDays = includeRestDays
            self.conflictStrategy = conflictStrategy
        }
    }

    // MARK: - Public

    static func preview(program: TrainingProgram, options: Options) -> Preview {
        let map = (try? ProgramPackAssetMapStore.load()) ?? .empty

        let missing = missingRoutineSlugs(program: program, map: map)
        let plan = buildPlan(program: program, options: options, map: map, allowMissingRoutines: true)

        let workouts = plan.filter { $0.kind == .workout }.count
        let days = Set(plan.map { dayKey(for: $0.startAt) }).count

        let range: ClosedRange<Date>? = {
            guard let first = plan.map(\.startAt).min(),
                  let last  = plan.map(\.startAt).max()
            else { return nil }
            return first...last
        }()

        return Preview(
            totalActivities: plan.count,
            workoutActivities: workouts,
            trainingDays: days,
            dateRange: range,
            missingRoutineSlugs: missing
        )
    }

    static func schedule(program: TrainingProgram, options: Options, context: ModelContext) throws -> Result {
        let map = (try? ProgramPackAssetMapStore.load()) ?? .empty
        let missing = missingRoutineSlugs(program: program, map: map)
        if !missing.isEmpty { throw ScheduleError.missingRoutines(missing) }

        let plan = buildPlan(program: program, options: options, map: map, allowMissingRoutines: false)

        var created = 0
        var skipped = 0
        var deleted = 0

        for item in plan {
            let conflicts = try fetchConflicts(start: item.startAt, end: item.endAt, context: context)

            if !conflicts.isEmpty {
                switch options.conflictStrategy {
                case .skipConflicts:
                    skipped += 1
                    continue

                case .replaceInSlot:
                    // never delete for all-day rest; treat as skip instead
                    if item.isAllDay {
                        skipped += 1
                        continue
                    }
                    for c in conflicts {
                        context.delete(c)
                        deleted += 1
                    }

                case .allowOverlap:
                    break
                }
            }

            let a = Activity(
                title: item.title,
                startAt: item.startAt,
                endAt: item.endAt,
                laneHint: item.laneHint,
                kind: item.kind,
                workoutRoutineId: item.workoutRoutineId
            )

            a.isAllDay = item.isAllDay
            a.status = .planned
            a.completedAt = nil
            a.workoutSessionId = nil

            a.plannedTitle = a.title
            a.plannedStartAt = a.startAt
            a.plannedEndAt = a.endAt

            a.dayKey = dayKey(for: a.startAt)
            a.templateId = nil
            a.generatedKey = nil

            context.insert(a)
            created += 1
        }

        try context.save()
        return Result(created: created, skipped: skipped, deleted: deleted)
    }

    // MARK: - Internals

    private struct PlannedItem {
        var title: String
        var startAt: Date
        var endAt: Date
        var isAllDay: Bool
        var kind: ActivityKind
        var laneHint: Int
        var workoutRoutineId: UUID?
    }

    private static func routineSlug(for day: TrainingDay) -> String? {
        // V2 rule: a TrainingDay must reference a routine slug
        let s = day.blocks.first(where: { $0.reference?.kind == .routine })?.reference?.slug
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (t?.isEmpty == false) ? t!.lowercased() : nil
    }

    private static func missingRoutineSlugs(program: TrainingProgram, map: ProgramPackAssetMap) -> [String] {
        var missing: Set<String> = []

        for w in program.weeks {
            for d in w.days {
                if d.isRestLikeDay {
                    continue
                }
                guard let slug = routineSlug(for: d) else {
                    missing.insert("Missing routine reference in “\(program.name)”")
                    continue
                }
                if map.routinesBySlug[slug] == nil {
                    missing.insert(slug)
                }
            }
        }
        return Array(missing).sorted()
    }

    private static func buildPlan(
        program: TrainingProgram,
        options: Options,
        map: ProgramPackAssetMap,
        allowMissingRoutines: Bool
    ) -> [PlannedItem] {
        let cal = Calendar.current
        let week0Start = cal.startOfDay(for: options.startDate)

        var out: [PlannedItem] = []

        for w in program.orderedWeeks {
            let weekStart = cal.date(byAdding: .day, value: (w.index - 1) * 7, to: week0Start) ?? week0Start

            // Map day indices into 1...7 (supports 0-based or 1-based; sequential fallback)
            let raw = w.days.map(\.index)
            let looksZeroBased = !raw.isEmpty && raw.allSatisfy { (0...6).contains($0) }
            let looksOneBased  = !raw.isEmpty && raw.allSatisfy { (1...7).contains($0) }

            func normalize(_ v: Int) -> Int? {
                if looksZeroBased { return v + 1 }
                if looksOneBased { return v }
                return nil
            }

            var dayByIndex: [Int: TrainingDay] = [:]
            for d in w.days {
                if let n = normalize(d.index), (1...7).contains(n) { dayByIndex[n] = d }
            }
            if dayByIndex.isEmpty && !w.days.isEmpty {
                let sorted = w.days.sorted { $0.index < $1.index }
                for (i, d) in sorted.enumerated() {
                    let slot = i + 1
                    guard slot <= 7 else { break }
                    dayByIndex[slot] = d
                }
            }

            let active = dayByIndex.keys.sorted()
            let minActive = active.first
            let maxActive = active.last

            for dayIndex in 1...7 {
                let dayStart = cal.date(byAdding: .day, value: dayIndex - 1, to: weekStart) ?? weekStart

                guard let day = dayByIndex[dayIndex] else {
                    // Rest only between active training days (keeps noise down)
                    if options.includeRestDays,
                       let lo = minActive, let hi = maxActive,
                       dayIndex >= lo, dayIndex <= hi
                    {
                        let end = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                        out.append(.init(
                            title: "Rest",
                            startAt: dayStart,
                            endAt: end,
                            isAllDay: true,
                            kind: .generic,
                            laneHint: 0,
                            workoutRoutineId: nil
                        ))
                    }
                    continue
                }

                // explicit rest block => all-day rest
                if day.blocks.contains(where: { $0.kind == .rest }) {
                    let end = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                    out.append(.init(
                        title: day.title.isEmpty ? "Rest" : day.title,
                        startAt: dayStart,
                        endAt: end,
                        isAllDay: true,
                        kind: .generic,
                        laneHint: 0,
                        workoutRoutineId: nil
                    ))
                    continue
                }

                let (hour, minute) = timeComponents(from: options.startTime)
                let startAt = cal.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart

                let duration = day.blocks.first(where: { $0.kind == .workout })?.estimatedMinutes ?? 60
                let endAt = cal.date(byAdding: .minute, value: max(20, duration), to: startAt) ?? startAt

                let slug = routineSlug(for: day)
                let routineId = slug.flatMap { map.routinesBySlug[$0] }

                if !allowMissingRoutines, routineId == nil {
                    continue
                }

                out.append(.init(
                    title: day.title.isEmpty ? "Workout" : day.title,
                    startAt: startAt,
                    endAt: endAt,
                    isAllDay: false,
                    kind: .workout,
                    laneHint: 0,
                    workoutRoutineId: routineId
                ))
            }
        }

        return out.sorted { $0.startAt < $1.startAt }
    }

    private static func timeComponents(from time: Date) -> (Int, Int) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        return (c.hour ?? 18, c.minute ?? 0)
    }

    private static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func fetchConflicts(start: Date, end: Date, context: ModelContext) throws -> [Activity] {
        let s = start
        let e = end
        let fd = FetchDescriptor<Activity>(
            predicate: #Predicate { a in
                a.startAt < e && ((a.endAt ?? a.startAt) > s)
            }
        )
        return try context.fetch(fd)
    }

    /// Returns the best day to open after scheduling:
    /// - First scheduled workout day if present
    /// - Otherwise first scheduled activity day
    static func firstPlannedDayToOpen(program: TrainingProgram, options: Options) -> Date? {
        let map = (try? ProgramPackAssetMapStore.load()) ?? .empty

        // Use the same plan as scheduling (do NOT allow missing routines when strict)
        let plan = buildPlan(program: program, options: options, map: map, allowMissingRoutines: false)
        guard !plan.isEmpty else { return nil }

        let cal = Calendar.current
        if let firstWorkout = plan.first(where: { $0.kind == .workout }) {
            return cal.startOfDay(for: firstWorkout.startAt)
        }
        return cal.startOfDay(for: plan[0].startAt)
    }
}
