import XCTest
@testable import workouttracker

final class ProgramPlannerTests: XCTestCase {

    func test_currentPosition_onStartDate_pointsToFirstRequiredDay() {
        let calendar = TestSupport.utcCalendar
        let startDate = TestSupport.date(2026, 1, 5, calendar: calendar)
        let assignment = ProgramAssignment(program: sampleProgram(), startDate: startDate)

        let position = ProgramPlanner.currentPosition(
            for: assignment,
            program: sampleProgram(),
            now: startDate,
            calendar: calendar
        )

        XCTAssertEqual(position.scheduledWeekIndex, 1)
        XCTAssertEqual(position.currentWeekIndex, 1)
        XCTAssertEqual(position.currentDayIndex, 1)
        XCTAssertEqual(position.nextActionableWeekIndex, 1)
        XCTAssertEqual(position.nextActionableDayIndex, 1)
        XCTAssertFalse(position.isBehindSchedule)
        XCTAssertFalse(position.isProgramComplete)
    }

    func test_nextActionableDay_prefersOutstandingMissedDay() {
        let calendar = TestSupport.utcCalendar
        let program = sampleProgram()
        let assignment = ProgramAssignment(program: program, startDate: TestSupport.date(2026, 1, 5, calendar: calendar))

        assignment.executionState?.completedDays.append(
            ProgramCompletedDay(programId: program.id, weekIndex: 1, dayIndex: 1, completedAt: TestSupport.date(2026, 1, 5, calendar: calendar))
        )

        let next = ProgramPlanner.nextActionableDay(
            for: assignment,
            program: program,
            now: TestSupport.date(2026, 1, 9, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(next?.weekIndex, 1)
        XCTAssertEqual(next?.dayIndex, 3)
        XCTAssertEqual(next?.state, .missed)
    }

    func test_plannedDays_marksCompletedMissedAndUpcomingStates() {
        let calendar = TestSupport.utcCalendar
        let program = sampleProgram()
        let assignment = ProgramAssignment(program: program, startDate: TestSupport.date(2026, 1, 5, calendar: calendar))

        assignment.executionState?.completedDays.append(
            ProgramCompletedDay(programId: program.id, weekIndex: 1, dayIndex: 1, completedAt: TestSupport.date(2026, 1, 5, calendar: calendar))
        )

        let days = ProgramPlanner.plannedDays(
            for: assignment,
            program: program,
            weekIndex: 1,
            now: TestSupport.date(2026, 1, 7, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(days.map(\.dayIndex), [1, 3, 5])
        XCTAssertEqual(days[0].state, .completed)
        XCTAssertEqual(days[1].state, .scheduledToday)
        XCTAssertEqual(days[2].state, .upcoming)
    }

    private func sampleProgram() -> TrainingProgram {
        TrainingProgram(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            slug: "linear-strength-4-week",
            name: "Linear Strength 4 Week",
            weeks: [
                ProgramWeek(
                    index: 1,
                    days: [
                        ProgramDay(index: 1, title: "Day 1"),
                        ProgramDay(index: 3, title: "Day 2"),
                        ProgramDay(index: 5, title: "Day 3")
                    ]
                ),
                ProgramWeek(
                    index: 2,
                    days: [
                        ProgramDay(index: 1, title: "Week 2 Day 1"),
                        ProgramDay(index: 3, title: "Week 2 Day 2")
                    ]
                )
            ],
            source: .bundled
        )
    }
}
