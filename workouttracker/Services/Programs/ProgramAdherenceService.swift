import Foundation

enum ProgramAdherenceService {

    static func weekCompletion(
        for assignment: ProgramAssignment,
        program: TrainingProgram,
        weekIndex: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProgramWeekCompletion {
        let plannedDays = ProgramPlanner.plannedDays(for: assignment, program: program, weekIndex: weekIndex, now: now, calendar: calendar)
        let required = plannedDays.filter(\.isRequired)
        let completed = required.filter { $0.state == .completed }.count
        let missed = required.filter { $0.state == .missed }.count
        let remaining = required.count - completed

        return ProgramWeekCompletion(
            weekIndex: weekIndex,
            requiredDays: required.count,
            completedRequiredDays: completed,
            missedRequiredDays: missed,
            remainingRequiredDays: max(0, remaining)
        )
    }

    static func summary(
        for assignment: ProgramAssignment,
        program: TrainingProgram,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProgramAdherenceSummary {
        let position = ProgramPlanner.currentPosition(for: assignment, program: program, now: now, calendar: calendar)
        let currentWeekCompletion = weekCompletion(
            for: assignment,
            program: program,
            weekIndex: position.currentWeekIndex,
            now: now,
            calendar: calendar
        )

        let allPlannedDays = program.orderedWeeks.flatMap { week in
            ProgramPlanner.plannedDays(for: assignment, program: program, weekIndex: week.index, now: now, calendar: calendar)
        }

        let requiredDays = allPlannedDays.filter(\.isRequired)
        let completedRequiredDays = requiredDays.filter { $0.state == .completed }.count
        let missedRequiredDays = requiredDays.filter { $0.state == .missed }.count
        let outstandingMissedDays = requiredDays.filter { $0.state == .missed }.count

        return ProgramAdherenceSummary(
            position: position,
            currentWeekCompletion: currentWeekCompletion,
            completedRequiredDays: completedRequiredDays,
            missedRequiredDays: missedRequiredDays,
            outstandingMissedDays: outstandingMissedDays,
            recommendation: recommendation(
                for: assignment,
                program: program,
                position: position,
                currentWeekCompletion: currentWeekCompletion,
                now: now,
                calendar: calendar
            )
        )
    }

    static func recommendation(
        for assignment: ProgramAssignment,
        program: TrainingProgram,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProgramRecommendation {
        let position = ProgramPlanner.currentPosition(for: assignment, program: program, now: now, calendar: calendar)
        let currentWeekCompletion = weekCompletion(
            for: assignment,
            program: program,
            weekIndex: position.currentWeekIndex,
            now: now,
            calendar: calendar
        )

        return recommendation(
            for: assignment,
            program: program,
            position: position,
            currentWeekCompletion: currentWeekCompletion,
            now: now,
            calendar: calendar
        )
    }

    private static func recommendation(
        for assignment: ProgramAssignment,
        program: TrainingProgram,
        position: ProgramPosition,
        currentWeekCompletion: ProgramWeekCompletion,
        now: Date,
        calendar: Calendar
    ) -> ProgramRecommendation {
        if position.isProgramComplete {
            return ProgramRecommendation(kind: .completeProgram, reason: .programFinished, weekIndex: nil, dayIndex: nil)
        }

        if currentWeekCompletion.missedRequiredDays > 0 {
            let weekStart = ProgramPlanner.weekStartDate(for: assignment, weekIndex: position.currentWeekIndex, calendar: calendar)
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

            if calendar.startOfDay(for: now) >= weekEnd {
                return ProgramRecommendation(
                    kind: .repeatWeek,
                    reason: .missedRequiredDays,
                    weekIndex: position.currentWeekIndex,
                    dayIndex: nil
                )
            }
        }

        if let nextDay = ProgramPlanner.nextActionableDay(for: assignment, program: program, now: now, calendar: calendar) {
            switch nextDay.state {
            case .missed:
                return ProgramRecommendation(
                    kind: .completeMissedDay,
                    reason: .outstandingMissedDay,
                    weekIndex: nextDay.weekIndex,
                    dayIndex: nextDay.dayIndex
                )
            case .scheduledToday, .upcoming:
                let kind: ProgramRecommendation.Kind = currentWeekCompletion.completedRequiredDays == 0 ? .startWeek : .advanceToNextDay
                let reason: ProgramRecommendation.Reason = currentWeekCompletion.completedRequiredDays == 0 ? .weekNotStarted : .nextIncompleteDay
                return ProgramRecommendation(
                    kind: kind,
                    reason: reason,
                    weekIndex: nextDay.weekIndex,
                    dayIndex: nextDay.dayIndex
                )
            case .completed, .rest:
                break
            }
        }

        return ProgramRecommendation(
            kind: .repeatWeek,
            reason: .missedRequiredDays,
            weekIndex: position.currentWeekIndex,
            dayIndex: nil
        )
    }
}
