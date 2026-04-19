import XCTest
import SwiftData
@testable import workouttracker

final class ProgramAssignmentModelTests: XCTestCase {

    @MainActor
    func test_assignmentInitialization_createsIndependentRuntimeState() throws {
        let context = try makeInMemoryContext()
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)

        let program = TrainingProgram(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            slug: "linear-strength-4-week",
            name: "Linear Strength 4 Week",
            weeks: [
                ProgramWeek(index: 1, days: [ProgramDay(index: 2, title: "Upper")])
            ],
            source: .bundled
        )

        let assignment = ProgramAssignment(program: program, startDate: startDate)
        context.insert(assignment)
        try context.save()

        let assignments = try context.fetch(FetchDescriptor<ProgramAssignment>())
        XCTAssertEqual(assignments.count, 1)
        XCTAssertEqual(assignments.first?.programId, program.id)
        XCTAssertEqual(assignments.first?.programSlug, "linear-strength-4-week")
        XCTAssertEqual(assignments.first?.programNameSnapshot, "Linear Strength 4 Week")
        XCTAssertEqual(assignments.first?.status, .active)
        XCTAssertEqual(assignments.first?.executionState?.currentWeekIndex, 1)
        XCTAssertEqual(assignments.first?.executionState?.currentDayIndex, 2)
        XCTAssertTrue(assignments.first?.executionState?.completedDays.isEmpty ?? false)
        XCTAssertTrue(assignments.first?.executionState?.missedDays.isEmpty ?? false)
    }

    @MainActor
    func test_runtimeStateRemainsSeparateFromTemplateData() throws {
        let context = try makeInMemoryContext()

        let program = TrainingProgram(
            slug: "hypertrophy-double-progression",
            name: "Hypertrophy Double Progression",
            weeks: [
                ProgramWeek(index: 1, days: [ProgramDay(index: 1, title: "Push")])
            ]
        )

        let assignment = ProgramAssignment(program: program, startDate: Date(timeIntervalSince1970: 1_700_100_000))
        let completed = ProgramCompletedDay(
            programId: assignment.programId,
            weekIndex: 1,
            dayIndex: 1,
            completionSource: .manual
        )

        assignment.executionState?.completedDays.append(completed)
        assignment.executionState?.currentWeekIndex = 2
        assignment.executionState?.currentDayIndex = nil

        context.insert(assignment)
        try context.save()

        XCTAssertEqual(program.weeks[0].days[0].title, "Push")
        XCTAssertEqual(program.weeks[0].days[0].prescriptions.count, 0)
        XCTAssertEqual(assignment.executionState?.completedDays.count, 1)
        XCTAssertEqual(assignment.executionState?.currentWeekIndex, 2)
        XCTAssertNil(assignment.executionState?.currentDayIndex)
    }

    @MainActor
    func test_assignmentStatusTransitions_pauseResumeAndComplete() throws {
        let program = TrainingProgram(name: "Deload", weeks: [ProgramWeek(index: 1, days: [ProgramDay(index: 1, title: "Light")])])
        let assignment = ProgramAssignment(program: program, startDate: Date())

        assignment.pause()
        XCTAssertEqual(assignment.status, .paused)

        assignment.resume()
        XCTAssertEqual(assignment.status, .active)

        assignment.complete()
        XCTAssertEqual(assignment.status, .completed)
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
}
