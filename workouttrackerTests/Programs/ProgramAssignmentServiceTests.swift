import XCTest
import SwiftData
@testable import workouttracker

final class ProgramAssignmentServiceTests: XCTestCase {

    @MainActor
    func test_activateProgram_pausesOtherActiveAssignments() throws {
        let context = try makeInMemoryContext()
        let firstProgram = makeProgram(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, slug: "first", name: "First")
        let secondProgram = makeProgram(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, slug: "second", name: "Second")

        let firstAssignment = ProgramAssignment(program: firstProgram, startDate: Date(timeIntervalSince1970: 1_700_000_000))
        let secondAssignment = ProgramAssignment(program: secondProgram, startDate: Date(timeIntervalSince1970: 1_700_010_000))
        context.insert(firstAssignment)
        context.insert(secondAssignment)
        try context.save()

        let activated = try ProgramAssignmentService.activateProgram(
            secondProgram,
            startDate: Date(timeIntervalSince1970: 1_700_020_000),
            anchorStrategy: .sequential,
            context: context,
            assignedAt: Date(timeIntervalSince1970: 1_700_030_000)
        )

        XCTAssertEqual(firstAssignment.status, .paused)
        XCTAssertEqual(activated.id, secondAssignment.id)
        XCTAssertEqual(activated.status, .active)
        XCTAssertEqual(activated.scheduleAnchorStrategy, .sequential)
    }

    @MainActor
    func test_activateProgram_resetsExistingExecutionStateProgress() throws {
        let context = try makeInMemoryContext()
        let program = makeProgram(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, slug: "program", name: "Program")
        let assignment = ProgramAssignment(program: program, startDate: Date(timeIntervalSince1970: 1_700_000_000))
        let executionState = try XCTUnwrap(assignment.executionState)
        executionState.currentWeekIndex = 3
        executionState.currentDayIndex = 4
        executionState.lastEvaluatedAt = Date(timeIntervalSince1970: 1_700_111_111)
        executionState.repeatedWeekIndexes = [2]
        executionState.deloadedWeekIndexes = [3]

        let completedDay = ProgramCompletedDay(programId: program.id, weekIndex: 2, dayIndex: 1)
        completedDay.executionState = executionState
        executionState.completedDays.append(completedDay)
        context.insert(completedDay)

        let missedDay = ProgramMissedDay(programId: program.id, weekIndex: 2, dayIndex: 2)
        missedDay.executionState = executionState
        executionState.missedDays.append(missedDay)
        context.insert(missedDay)

        context.insert(assignment)
        try context.save()

        let activated = try ProgramAssignmentService.activateProgram(
            program,
            startDate: Date(timeIntervalSince1970: 1_700_222_222),
            anchorStrategy: .calendarAligned,
            context: context,
            assignedAt: Date(timeIntervalSince1970: 1_700_333_333)
        )

        let refreshedState = try XCTUnwrap(activated.executionState)
        XCTAssertEqual(refreshedState.currentWeekIndex, 1)
        XCTAssertEqual(refreshedState.currentDayIndex, 1)
        XCTAssertNil(refreshedState.lastEvaluatedAt)
        XCTAssertTrue(refreshedState.completedDays.isEmpty)
        XCTAssertTrue(refreshedState.missedDays.isEmpty)
        XCTAssertTrue(refreshedState.repeatedWeekIndexes.isEmpty)
        XCTAssertTrue(refreshedState.deloadedWeekIndexes.isEmpty)

        XCTAssertTrue(try context.fetch(FetchDescriptor<ProgramCompletedDay>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ProgramMissedDay>()).isEmpty)
    }

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ProgramAssignment.self,
            ProgramExecutionState.self,
            ProgramCompletedDay.self,
            ProgramMissedDay.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeProgram(id: UUID, slug: String, name: String) -> TrainingProgram {
        TrainingProgram(
            id: id,
            slug: slug,
            name: name,
            weeks: [ProgramWeek(index: 1, days: [ProgramDay(index: 1, title: "Day 1")])],
            source: .bundled
        )
    }
}
