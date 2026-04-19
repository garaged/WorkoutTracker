import Foundation

enum ProgramPlanner {

    static func currentPosition(
        for assignment: ProgramAssignment,
        program: TrainingProgram,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProgramPosition {
        let plan = planningState(for: assignment, program: program, now: now, calendar: calendar)

        return ProgramPosition(
            assignmentID: assignment.id,
            programID: program.id,
            asOfDate: plan.todayStart,
            scheduledWeekIndex: plan.scheduledWeekIndex,
            currentWeekIndex: plan.currentWeekIndex,
            currentDayIndex: plan.currentDayIndex,
            nextActionableWeekIndex: plan.nextActionable?.weekIndex,
            nextActionableDayIndex: plan.nextActionable?.dayIndex,
            isBehindSchedule: plan.isBehindSchedule,
            isProgramComplete: plan.isProgramComplete
        )
    }

    static func nextActionableDay(
        for assignment: ProgramAssignment,
        program: TrainingProgram,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlannedProgramDay? {
        planningState(for: assignment, program: program, now: now, calendar: calendar).nextActionable
    }

    static func plannedDays(
        for assignment: ProgramAssignment,
        program: TrainingProgram,
        weekIndex: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedProgramDay] {
        let plan = planningState(for: assignment, program: program, now: now, calendar: calendar)
        return plan.plannedDaysByWeek[weekIndex] ?? []
    }

    fileprivate struct PlanningState {
        let todayStart: Date
        let scheduledWeekIndex: Int
        let currentWeekIndex: Int
        let currentDayIndex: Int?
        let nextActionable: PlannedProgramDay?
        let isBehindSchedule: Bool
        let isProgramComplete: Bool
        let plannedDaysByWeek: [Int: [PlannedProgramDay]]
    }

    fileprivate static func planningState(
        for assignment: ProgramAssignment,
        program: TrainingProgram,
        now: Date,
        calendar: Calendar
    ) -> PlanningState {
        let todayStart = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: assignment.startDate)
        let scheduledWeekIndex = scheduledWeekIndex(
            startDate: startDay,
            now: todayStart,
            durationWeeks: max(program.durationWeeks, 1),
            calendar: calendar
        )

        let completedKeys = Set((assignment.executionState?.completedDays ?? []).map(dayKey))
        let missedKeys = Set((assignment.executionState?.missedDays ?? []).map(dayKey))

        var plannedByWeek: [Int: [PlannedProgramDay]] = [:]
        var currentWeekIndex: Int = min(max(scheduledWeekIndex, 1), max(program.durationWeeks, 1))
        var currentDayIndex: Int? = nil
        var nextActionable: PlannedProgramDay? = nil
        var foundIncompleteWeek = false
        var hasMissedBeforeScheduledWeek = false

        for week in program.orderedWeeks {
            let days = plannedDaysForWeek(
                week,
                assignment: assignment,
                currentWeekIndex: currentWeekIndex,
                todayStart: todayStart,
                completedKeys: completedKeys,
                missedKeys: missedKeys,
                calendar: calendar
            )

            plannedByWeek[week.index] = days

            if !foundIncompleteWeek,
               week.index <= scheduledWeekIndex,
               days.contains(where: { $0.isRequired && $0.state != .completed }) {
                currentWeekIndex = week.index
                currentDayIndex = days.first(where: { $0.isRequired && $0.state != .completed })?.dayIndex
                foundIncompleteWeek = true
            }

            if week.index < scheduledWeekIndex,
               days.contains(where: { $0.isRequired && $0.state == .missed }) {
                hasMissedBeforeScheduledWeek = true
            }

            if nextActionable == nil {
                nextActionable = days.first(where: { $0.isNextActionable })
            }
        }

        let isProgramComplete = program.orderedWeeks.allSatisfy { week in
            let days = plannedByWeek[week.index] ?? []
            return !days.contains(where: { $0.isRequired && $0.state != .completed })
        }

        if isProgramComplete {
            currentDayIndex = nil
            nextActionable = nil
        } else if !foundIncompleteWeek {
            let clampedWeek = min(max(scheduledWeekIndex, 1), max(program.durationWeeks, 1))
            currentWeekIndex = clampedWeek
            currentDayIndex = plannedByWeek[clampedWeek]?.first(where: { $0.isRequired && $0.state != .completed })?.dayIndex
        }

        return PlanningState(
            todayStart: todayStart,
            scheduledWeekIndex: scheduledWeekIndex,
            currentWeekIndex: currentWeekIndex,
            currentDayIndex: currentDayIndex,
            nextActionable: nextActionable,
            isBehindSchedule: hasMissedBeforeScheduledWeek || currentWeekIndex < scheduledWeekIndex,
            isProgramComplete: isProgramComplete,
            plannedDaysByWeek: plannedByWeek
        )
    }

    fileprivate static func plannedDaysForWeek(
        _ week: ProgramWeek,
        assignment: ProgramAssignment,
        currentWeekIndex: Int,
        todayStart: Date,
        completedKeys: Set<String>,
        missedKeys: Set<String>,
        calendar: Calendar
    ) -> [PlannedProgramDay] {
        let weekStart = weekStartDate(for: assignment, weekIndex: week.index, calendar: calendar)
        let requiredDays = normalizedDays(for: week)
        let actionableKey = requiredDays.first { item in
            let key = dayKey(forWeek: week.index, dayIndex: item.day.index)
            return !completedKeys.contains(key)
        }.map { dayKey(forWeek: week.index, dayIndex: $0.day.index) }

        return requiredDays.map { item in
            let scheduledDate = calendar.date(byAdding: .day, value: item.slot - 1, to: weekStart) ?? weekStart
            let key = dayKey(forWeek: week.index, dayIndex: item.day.index)
            let isRequired = !item.day.isRestLikeDay

            let state: PlannedProgramDay.State
            if !isRequired {
                state = .rest
            } else if completedKeys.contains(key) {
                state = .completed
            } else if missedKeys.contains(key) || scheduledDate < todayStart {
                state = .missed
            } else if calendar.isDate(scheduledDate, inSameDayAs: todayStart) {
                state = .scheduledToday
            } else {
                state = .upcoming
            }

            return PlannedProgramDay(
                id: "\(week.index)-\(item.day.index)",
                weekIndex: week.index,
                dayIndex: item.day.index,
                title: item.day.title,
                scheduledDate: scheduledDate,
                kind: item.day.kind,
                isRequired: isRequired,
                state: state,
                routineSlug: item.day.primaryRoutineReference?.slug,
                isCurrentWeek: week.index == currentWeekIndex,
                isNextActionable: actionableKey == key && isRequired && state != .completed
            )
        }
    }

    static func weekStartDate(
        for assignment: ProgramAssignment,
        weekIndex: Int,
        calendar: Calendar
    ) -> Date {
        let start = calendar.startOfDay(for: assignment.startDate)
        return calendar.date(byAdding: .day, value: (weekIndex - 1) * 7, to: start) ?? start
    }

    fileprivate static func scheduledWeekIndex(
        startDate: Date,
        now: Date,
        durationWeeks: Int,
        calendar: Calendar
    ) -> Int {
        guard now >= startDate else { return 1 }
        let days = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
        return min(max((days / 7) + 1, 1), durationWeeks)
    }

    fileprivate static func normalizedDays(for week: ProgramWeek) -> [(slot: Int, day: ProgramDay)] {
        let raw = week.days.map(\.index)
        let looksOneBased = !raw.isEmpty && raw.allSatisfy { (1...7).contains($0) }
        let looksZeroBased = !raw.isEmpty && raw.contains(0) && raw.allSatisfy { (0...6).contains($0) }

        func normalize(_ value: Int) -> Int? {
            if looksOneBased { return value }
            if looksZeroBased { return value + 1 }
            return nil
        }

        var bySlot: [Int: ProgramDay] = [:]
        for day in week.days {
            if let slot = normalize(day.index), (1...7).contains(slot) {
                bySlot[slot] = day
            }
        }

        if bySlot.isEmpty {
            for (offset, day) in week.orderedDays.enumerated() where offset < 7 {
                bySlot[offset + 1] = day
            }
        }

        return bySlot.keys.sorted().compactMap { slot in
            guard let day = bySlot[slot] else { return nil }
            return (slot, day)
        }
    }

    fileprivate static func dayKey(for day: ProgramCompletedDay) -> String {
        dayKey(forWeek: day.weekIndex, dayIndex: day.dayIndex)
    }

    fileprivate static func dayKey(for day: ProgramMissedDay) -> String {
        dayKey(forWeek: day.weekIndex, dayIndex: day.dayIndex)
    }

    fileprivate static func dayKey(forWeek weekIndex: Int, dayIndex: Int) -> String {
        "\(weekIndex)-\(dayIndex)"
    }
}
