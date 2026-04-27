import XCTest
import SwiftData
@testable import workouttracker

final class ProgramExecutionUpdateServiceTests: XCTestCase {

    @MainActor
    func test_recordCompletedSession_addsCompletedDayAndClearsMatchingMissedDay() throws {
        let context = try makeInMemoryContext()
        let assignment = makeAssignment()
        let executionState = try XCTUnwrap(assignment.executionState)

        let missedDay = ProgramMissedDay(programId: assignment.programId, weekIndex: 1, dayIndex: 2)
        missedDay.executionState = executionState
        executionState.missedDays.append(missedDay)

        context.insert(assignment)
        context.insert(missedDay)
        try context.save()

        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceRoutineId: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"),
            sourceRoutineNameSnapshot: "Upper B",
            programAssignmentId: assignment.id,
            sourceProgramId: assignment.programId,
            sourceProgramWeekIndex: 1,
            sourceProgramDayIndex: 2
        )
        session.status = .completed
        session.endedAt = Date(timeIntervalSince1970: 1_700_003_600)
        context.insert(session)

        try ProgramExecutionUpdateService.recordCompletedSession(
            session,
            context: context,
            now: Date(timeIntervalSince1970: 1_700_004_000)
        )

        XCTAssertEqual(executionState.completedDays.count, 1)
        XCTAssertTrue(executionState.missedDays.isEmpty)
        XCTAssertEqual(executionState.currentWeekIndex, 1)
        XCTAssertEqual(executionState.currentDayIndex, 2)
        XCTAssertEqual(executionState.lastEvaluatedAt, Date(timeIntervalSince1970: 1_700_004_000))

        let completedDay = try XCTUnwrap(executionState.completedDays.first)
        XCTAssertEqual(completedDay.completionSource, .workoutSession)
        XCTAssertEqual(completedDay.workoutSessionId, session.id)
        XCTAssertEqual(completedDay.sourceRoutineNameSnapshot, "Upper B")
    }

    @MainActor
    func test_recordCompletedSession_updatesExistingCompletedDayWithoutDuplicating() throws {
        let context = try makeInMemoryContext()
        let assignment = makeAssignment()
        let executionState = try XCTUnwrap(assignment.executionState)
        let existingCompletedDay = ProgramCompletedDay(
            programId: assignment.programId,
            weekIndex: 1,
            dayIndex: 2,
            completedAt: Date(timeIntervalSince1970: 1_700_001_000),
            completionSource: .manual
        )
        existingCompletedDay.executionState = executionState
        executionState.completedDays.append(existingCompletedDay)

        context.insert(assignment)
        context.insert(existingCompletedDay)
        try context.save()

        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceRoutineId: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"),
            sourceRoutineNameSnapshot: "Upper B",
            programAssignmentId: assignment.id,
            sourceProgramId: assignment.programId,
            sourceProgramWeekIndex: 1,
            sourceProgramDayIndex: 2
        )
        session.status = .completed
        session.endedAt = Date(timeIntervalSince1970: 1_700_003_600)
        context.insert(session)

        try ProgramExecutionUpdateService.recordCompletedSession(session, context: context)

        XCTAssertEqual(executionState.completedDays.count, 1)
        XCTAssertEqual(existingCompletedDay.completionSource, .workoutSession)
        XCTAssertEqual(existingCompletedDay.workoutSessionId, session.id)
        XCTAssertEqual(existingCompletedDay.sourceRoutineNameSnapshot, "Upper B")
        XCTAssertEqual(existingCompletedDay.completedAt, session.endedAt)
    }

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ProgramAssignment.self,
            ProgramExecutionState.self,
            ProgramCompletedDay.self,
            ProgramMissedDay.self,
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeAssignment() -> ProgramAssignment {
        let program = TrainingProgram(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            slug: "linear-strength",
            name: "Linear Strength",
            weeks: [ProgramWeek(index: 1, days: [ProgramDay(index: 2, title: "Upper B")])],
            source: .bundled
        )
        return ProgramAssignment(program: program, startDate: Date(timeIntervalSince1970: 1_700_000_000))
    }
}
