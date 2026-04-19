import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class ProgramAdherenceServiceTests: XCTestCase {

    func test_weekCompletion_countsCompletedMissedAndRemainingRequiredDays() {
        let calendar = TestSupport.utcCalendar
        let program = sampleProgram()
        let assignment = ProgramAssignment(program: program, startDate: TestSupport.date(2026, 1, 5, calendar: calendar))

        assignment.executionState?.completedDays.append(
            ProgramCompletedDay(programId: program.id, weekIndex: 1, dayIndex: 1, completedAt: TestSupport.date(2026, 1, 5, calendar: calendar))
        )

        let completion = ProgramAdherenceService.weekCompletion(
            for: assignment,
            program: program,
            weekIndex: 1,
            now: TestSupport.date(2026, 1, 9, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(completion.requiredDays, 3)
        XCTAssertEqual(completion.completedRequiredDays, 1)
        XCTAssertEqual(completion.missedRequiredDays, 1)
        XCTAssertEqual(completion.remainingRequiredDays, 2)
        XCTAssertFalse(completion.isComplete)
    }

    func test_summary_generatesRepeatWeekRecommendation_whenWeekEndedWithMissedDays() {
        let calendar = TestSupport.utcCalendar
        let program = sampleProgram()
        let assignment = ProgramAssignment(program: program, startDate: TestSupport.date(2026, 1, 5, calendar: calendar))

        assignment.executionState?.completedDays.append(
            ProgramCompletedDay(programId: program.id, weekIndex: 1, dayIndex: 1, completedAt: TestSupport.date(2026, 1, 5, calendar: calendar))
        )

        let summary = ProgramAdherenceService.summary(
            for: assignment,
            program: program,
            now: TestSupport.date(2026, 1, 13, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(summary.recommendation.kind, .repeatWeek)
        XCTAssertEqual(summary.recommendation.reason, .missedRequiredDays)
        XCTAssertEqual(summary.recommendation.weekIndex, 1)
        XCTAssertTrue(summary.position.isBehindSchedule)
    }

    func test_summary_generatesAdvanceRecommendation_forNextIncompleteDay() {
        let calendar = TestSupport.utcCalendar
        let program = sampleProgram()
        let assignment = ProgramAssignment(program: program, startDate: TestSupport.date(2026, 1, 5, calendar: calendar))

        assignment.executionState?.completedDays.append(
            ProgramCompletedDay(programId: program.id, weekIndex: 1, dayIndex: 1, completedAt: TestSupport.date(2026, 1, 5, calendar: calendar))
        )
        assignment.executionState?.completedDays.append(
            ProgramCompletedDay(programId: program.id, weekIndex: 1, dayIndex: 3, completedAt: TestSupport.date(2026, 1, 7, calendar: calendar))
        )

        let summary = ProgramAdherenceService.summary(
            for: assignment,
            program: program,
            now: TestSupport.date(2026, 1, 8, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(summary.recommendation.kind, .advanceToNextDay)
        XCTAssertEqual(summary.recommendation.reason, .nextIncompleteDay)
        XCTAssertEqual(summary.recommendation.weekIndex, 1)
        XCTAssertEqual(summary.recommendation.dayIndex, 5)
    }

    func test_programSessionStart_preservesProgramProvenance() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let calendar = TestSupport.utcCalendar

        let routine = try TestSupport.insertRoutine(context: context)
        let program = sampleProgram()
        let assignment = ProgramAssignment(program: program, startDate: TestSupport.date(2026, 1, 5, calendar: calendar))
        context.insert(assignment)
        try context.save()

        let day = try XCTUnwrap(program.weeks.first?.days.first)
        let session = try WorkoutSessionStarter.startSession(
            from: routine,
            assignment: assignment,
            program: program,
            weekIndex: 1,
            day: day,
            context: context,
            now: TestSupport.date(2026, 1, 5, 7, 0, calendar: calendar)
        )

        XCTAssertEqual(session.programAssignmentId, assignment.id)
        XCTAssertEqual(session.sourceProgramId, program.id)
        XCTAssertEqual(session.sourceProgramWeekIndex, 1)
        XCTAssertEqual(session.sourceProgramDayIndex, day.index)
        XCTAssertEqual(session.sourceRoutineId, routine.id)
    }

    func test_programSessionStart_carriesPrescriptionLinkageAndTargetsIntoSessionExercises() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let calendar = TestSupport.utcCalendar

        let routine = try TestSupport.insertRoutine(
            setPlans: [(10, 90, 120), (10, 90, 120)],
            context: context
        )

        let exercise = try XCTUnwrap(routine.items.first?.exercise)
        let lowerPrescription = ProgramPrescription(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            order: 1,
            exerciseId: exercise.id,
            exerciseNameSnapshot: exercise.name,
            targetSets: 3,
            targetReps: 5,
            targetWeight: 100,
            weightUnit: .kg,
            targetRPE: 8.0,
            progressionRules: [.fixedLoadIncrease(step: 2.5)]
        )

        let day = ProgramDay(index: 1, title: "Lower", prescriptions: [lowerPrescription])
        let program = TrainingProgram(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            slug: "prescription-link-test",
            name: "Prescription Link Test",
            weeks: [ProgramWeek(index: 1, days: [day])],
            source: .bundled
        )

        let assignment = ProgramAssignment(program: program, startDate: TestSupport.date(2026, 1, 5, calendar: calendar))
        context.insert(assignment)
        try context.save()

        let session = try WorkoutSessionStarter.startSession(
            from: routine,
            assignment: assignment,
            program: program,
            weekIndex: 1,
            day: day,
            context: context,
            now: TestSupport.date(2026, 1, 5, 7, 0, calendar: calendar)
        )

        let sessionExercise = try XCTUnwrap(session.exercises.first)
        XCTAssertEqual(sessionExercise.sourceProgramPrescriptionId, lowerPrescription.id)

        let setLogs = sessionExercise.setLogs.sorted { $0.order < $1.order }
        XCTAssertEqual(setLogs.count, 3)
        XCTAssertTrue(setLogs.allSatisfy { $0.targetReps == 5 })
        XCTAssertTrue(setLogs.allSatisfy { $0.targetWeight == 100 })
        XCTAssertTrue(setLogs.allSatisfy { $0.targetWeightUnit == .kg })
        XCTAssertTrue(setLogs.allSatisfy { $0.targetRPE == 8.0 })

        // Prefill behavior should mirror the updated prescription targets, not the routine defaults.
        XCTAssertTrue(setLogs.allSatisfy { $0.reps == 5 })
        XCTAssertTrue(setLogs.allSatisfy { $0.weight == 100 })
        XCTAssertTrue(setLogs.allSatisfy { $0.rpe == 8.0 })
    }

    func test_nonProgramSessionStart_leavesProgramLinkageFieldsNil() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let calendar = TestSupport.utcCalendar

        let routine = try TestSupport.insertRoutine(
            setPlans: [(8, 85, 90), (8, 85, 90)],
            context: context
        )

        let session = try WorkoutSessionStarter.startSession(
            from: routine,
            context: context,
            now: TestSupport.date(2026, 1, 5, 7, 0, calendar: calendar)
        )

        XCTAssertNil(session.programAssignmentId)
        XCTAssertNil(session.sourceProgramId)
        XCTAssertNil(session.sourceProgramWeekIndex)
        XCTAssertNil(session.sourceProgramDayIndex)

        let sessionExercise = try XCTUnwrap(session.exercises.first)
        XCTAssertNil(sessionExercise.sourceProgramPrescriptionId)

        let setLogs = sessionExercise.setLogs.sorted { $0.order < $1.order }
        XCTAssertEqual(setLogs.count, 2)
        XCTAssertTrue(setLogs.allSatisfy { $0.targetReps == 8 })
        XCTAssertTrue(setLogs.allSatisfy { $0.targetWeight == 85 })
        XCTAssertTrue(setLogs.allSatisfy { $0.targetWeightUnit == .kg })
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
