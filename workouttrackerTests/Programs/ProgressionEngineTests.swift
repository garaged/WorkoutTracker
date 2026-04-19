import XCTest
@testable import workouttracker

final class ProgressionEngineTests: XCTestCase {

    func test_successfulCompletion_leadsToFixedLoadIncrease() {
        let program = fixedLoadProgram()
        let session = makeCompletedSession(
            program: program,
            weekIndex: 1,
            dayIndex: 1,
            sourceProgramPrescriptionId: program.weeks[0].days[0].prescriptions[0].id,
            reps: [5, 5, 5],
            weight: [100, 100, 100]
        )

        let decision = ProgressionEngine.evaluate(session: session, program: program)

        XCTAssertEqual(decision.action, .increase)
        XCTAssertEqual(decision.reason, .prescriptionsProgressed)
        XCTAssertEqual(decision.adjustments.first?.action, .increaseLoad)
        XCTAssertEqual(decision.adjustments.first?.nextTargetWeight, 102.5)
    }

    func test_partialCompletion_leadsToHold() {
        let program = fixedLoadProgram()
        let session = makeCompletedSession(
            program: program,
            weekIndex: 1,
            dayIndex: 1,
            sourceProgramPrescriptionId: program.weeks[0].days[0].prescriptions[0].id,
            reps: [5, 4],
            weight: [100, 100]
        )

        let decision = ProgressionEngine.evaluate(session: session, program: program)

        XCTAssertEqual(decision.action, .hold)
        XCTAssertEqual(decision.reason, .targetNotMet)
        XCTAssertEqual(decision.adjustments.first?.action, .hold)
        XCTAssertEqual(decision.adjustments.first?.reason, .failedTarget)
    }

    func test_failureThreshold_triggersRepeatWeekRecommendation() {
        let program = repeatThresholdProgram()
        let session = makeCompletedSession(
            program: program,
            weekIndex: 1,
            dayIndex: 1,
            sourceProgramPrescriptionId: program.weeks[0].days[0].prescriptions[0].id,
            reps: [5],
            weight: [100]
        )

        let decision = ProgressionEngine.evaluate(session: session, program: program)

        XCTAssertEqual(decision.action, .repeatWeek)
        XCTAssertEqual(decision.reason, .failureThresholdReached)
        XCTAssertTrue(decision.adjustments.first?.suggestsRepeatWeek ?? false)
    }

    func test_scheduledDeload_appliesReducedTargets() {
        let program = deloadProgram()
        let session = makeCompletedSession(
            program: program,
            weekIndex: 4,
            dayIndex: 1,
            sourceProgramPrescriptionId: program.weeks[0].days[0].prescriptions[0].id,
            reps: [5, 5, 5],
            weight: [100, 100, 100]
        )

        let decision = ProgressionEngine.evaluate(session: session, program: program)

        XCTAssertEqual(decision.action, .deload)
        XCTAssertEqual(decision.reason, .scheduledDeload)
        XCTAssertEqual(decision.adjustments.first?.action, .deload)
        XCTAssertEqual(decision.adjustments.first?.nextTargetWeight, 90)
    }

    func test_doubleProgression_increasesRepsBeforeLoad() {
        let program = doubleProgressionProgram(targetReps: 8)
        let session = makeCompletedSession(
            program: program,
            weekIndex: 1,
            dayIndex: 1,
            sourceProgramPrescriptionId: program.weeks[0].days[0].prescriptions[0].id,
            reps: [9, 9, 9],
            weight: [80, 80, 80]
        )

        let decision = ProgressionEngine.evaluate(session: session, program: program)

        XCTAssertEqual(decision.action, .increase)
        XCTAssertEqual(decision.adjustments.first?.action, .increaseReps)
        XCTAssertEqual(decision.adjustments.first?.nextTargetReps, 9)
        XCTAssertEqual(decision.adjustments.first?.nextTargetWeight, 80)
    }

    func test_doubleProgression_increasesLoadAfterRepRangeMaxed() {
        let program = doubleProgressionProgram(targetReps: 12)
        let session = makeCompletedSession(
            program: program,
            weekIndex: 1,
            dayIndex: 1,
            sourceProgramPrescriptionId: program.weeks[0].days[0].prescriptions[0].id,
            reps: [12, 12, 12],
            weight: [80, 80, 80]
        )

        let decision = ProgressionEngine.evaluate(session: session, program: program)

        XCTAssertEqual(decision.action, .increase)
        XCTAssertEqual(decision.adjustments.first?.action, .increaseLoad)
        XCTAssertEqual(decision.adjustments.first?.nextTargetWeight, 82.5)
        XCTAssertEqual(decision.adjustments.first?.nextTargetReps, 8)
    }

    func test_invalidOrInsufficientInput_resolvesConservatively() {
        let program = invalidRuleProgram()
        let session = makeCompletedSession(
            program: program,
            weekIndex: 1,
            dayIndex: 1,
            sourceProgramPrescriptionId: program.weeks[0].days[0].prescriptions[0].id,
            reps: [5, 5, 5],
            weight: [100, 100, 100]
        )

        let decision = ProgressionEngine.evaluate(session: session, program: program)

        XCTAssertEqual(decision.action, .hold)
        XCTAssertEqual(decision.reason, .invalidRuleConfiguration)
        XCTAssertEqual(decision.adjustments.first?.reason, .invalidRuleConfiguration)
    }

    private func fixedLoadProgram() -> TrainingProgram {
        makeProgram(
            prescription: ProgramPrescription(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                order: 1,
                exerciseId: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                exerciseNameSnapshot: "Back Squat",
                targetSets: 3,
                targetReps: 5,
                targetWeight: 100,
                weightUnit: .kg,
                progressionRules: [.fixedLoadIncrease(step: 2.5)]
            )
        )
    }

    private func repeatThresholdProgram() -> TrainingProgram {
        makeProgram(
            prescription: ProgramPrescription(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                order: 1,
                exerciseId: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                exerciseNameSnapshot: "Back Squat",
                targetSets: 3,
                targetReps: 5,
                targetWeight: 100,
                weightUnit: .kg,
                progressionRules: [.repeatWeekOnFailureThreshold(failedSets: 2)]
            )
        )
    }

    private func deloadProgram() -> TrainingProgram {
        makeProgram(
            weekIndex: 4,
            prescription: ProgramPrescription(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                order: 1,
                exerciseId: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                exerciseNameSnapshot: "Back Squat",
                targetSets: 3,
                targetReps: 5,
                targetWeight: 100,
                weightUnit: .kg,
                progressionRules: [.deloadEvery(weeks: 4, percent: 0.1)]
            )
        )
    }

    private func doubleProgressionProgram(targetReps: Int) -> TrainingProgram {
        makeProgram(
            prescription: ProgramPrescription(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                order: 1,
                exerciseId: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                exerciseNameSnapshot: "Back Squat",
                targetSets: 3,
                targetReps: targetReps,
                targetWeight: 80,
                weightUnit: .kg,
                progressionRules: [.doubleProgression(minReps: 8, maxReps: 12, loadStep: 2.5)]
            )
        )
    }

    private func invalidRuleProgram() -> TrainingProgram {
        makeProgram(
            prescription: ProgramPrescription(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                order: 1,
                exerciseId: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                exerciseNameSnapshot: "Back Squat",
                targetSets: 3,
                targetReps: 5,
                targetWeight: 100,
                weightUnit: .kg,
                progressionRules: [.doubleProgression(minReps: 10, maxReps: 8, loadStep: 2.5)]
            )
        )
    }

    private func makeProgram(prescription: ProgramPrescription) -> TrainingProgram {
        makeProgram(weekIndex: 1, prescription: prescription)
    }

    private func makeProgram(
        weekIndex: Int,
        prescription: ProgramPrescription
    ) -> TrainingProgram {
        TrainingProgram(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            slug: "sample-program",
            name: "Sample Program",
            weeks: [
                ProgramWeek(
                    index: weekIndex,
                    days: [
                        ProgramDay(index: 1, title: "Day 1", prescriptions: [prescription])
                    ]
                )
            ],
            source: .bundled
        )
    }

    private func makeCompletedSession(
        program: TrainingProgram,
        weekIndex: Int,
        dayIndex: Int,
        sourceProgramPrescriptionId: UUID,
        reps: [Int],
        weight: [Double]
    ) -> WorkoutSession {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceRoutineId: nil,
            sourceRoutineNameSnapshot: "Program Session",
            linkedActivityId: nil,
            programAssignmentId: UUID(uuidString: "99999999-2222-3333-4444-555555555555"),
            sourceProgramId: program.id,
            sourceProgramWeekIndex: weekIndex,
            sourceProgramDayIndex: dayIndex
        )
        session.status = .completed
        session.endedAt = Date(timeIntervalSince1970: 1_700_000_600)

        let exercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            exerciseNameSnapshot: "Back Squat",
            sourceProgramPrescriptionId: sourceProgramPrescriptionId,
            session: session
        )

        exercise.setLogs = zip(reps, weight).enumerated().map { index, values in
            let log = WorkoutSetLog(
                order: index,
                reps: values.0,
                weight: values.1,
                weightUnit: .kg,
                completed: true,
                completedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index * 60)),
                targetReps: 5,
                targetWeight: values.1,
                targetWeightUnit: .kg,
                sessionExercise: exercise
            )
            return log
        }

        session.exercises = [exercise]
        return session
    }
}
