import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class WorkoutReopenAndNewSessionLinkingIntegrationTests: XCTestCase {

    func test_reopenForContinuation_keepsLogs_andResetsStatus() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let a = Activity(title: "W", startAt: Date(), endAt: Date())
        a.kind = .workout
        context.insert(a)

        // Create a completed session with one exercise and one completed set
        let exT = WorkoutSessionFactory.ExerciseTemplate(
            order: 0,
            exerciseId: UUID(),
            nameSnapshot: "Bench",
            notes: nil,
            sets: [.init(order: 0, targetReps: 10, targetWeight: 100, targetWeightUnit: .kg, targetRPE: nil, targetRestSeconds: 60)]
        )
        let s = WorkoutSessionFactory.makeSession(
            linkedActivityId: a.id,
            sourceRoutineId: nil,
            sourceRoutineNameSnapshot: nil,
            exercises: [exT],
            prefillActualsFromTargets: true
        )
        s.status = .completed
        s.endedAt = Date()
        s.exercises[0].setLogs[0].completed = true
        s.exercises[0].setLogs[0].completedAt = Date()

        context.insert(s)
        a.workoutSessionId = s.id
        try context.save()

        // Reopen
        s.reopenForContinuation()
        try context.save()

        XCTAssertEqual(s.status, .inProgress)
        XCTAssertNil(s.endedAt)

        // Logs still there
        XCTAssertEqual(s.exercises.count, 1)
        XCTAssertEqual(s.exercises[0].setLogs.count, 1)
        XCTAssertTrue(s.exercises[0].setLogs[0].completed) // keep logged truth
    }

    func test_startNewSession_createsNewActivityAndDoesNotOverwriteOldActivitySessionLink() throws {
        let cal = TestSupport.utcCalendar
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let routine = try TestSupport.insertRoutine(context: context)

        // Completed activity + session
        let a0 = Activity(title: "W1", startAt: TestSupport.date(2026, 1, 10, 9, 0, calendar: cal), endAt: TestSupport.date(2026, 1, 10, 10, 0, calendar: cal), kind: .workout, workoutRoutineId: routine.id)
        context.insert(a0)

        let s0 = try WorkoutSessionStarter.startOrResumeSession(for: a0, context: context, now: TestSupport.date(2026, 1, 10, 9, 0, calendar: cal))
        s0.status = .completed
        s0.endedAt = TestSupport.date(2026, 1, 10, 10, 0, calendar: cal)
        a0.status = .done
        try context.save()

        let oldSessionId = a0.workoutSessionId
        XCTAssertEqual(oldSessionId, s0.id)

        // "Start new session" should create a new Activity occurrence (history preservation)
        let a1 = Activity(
            title: a0.title,
            startAt: TestSupport.date(2026, 1, 10, 18, 0, calendar: cal),
            endAt: TestSupport.date(2026, 1, 10, 19, 0, calendar: cal),
            laneHint: a0.laneHint,
            kind: .workout,
            workoutRoutineId: a0.workoutRoutineId
        )
        a1.workoutSessionId = nil // critical
        context.insert(a1)
        try context.save()

        let s1 = try WorkoutSessionStarter.startOrResumeSession(for: a1, context: context, now: TestSupport.date(2026, 1, 10, 18, 0, calendar: cal))

        // Old activity still points to its completed session
        XCTAssertEqual(a0.workoutSessionId, oldSessionId)

        // New activity has a different session
        XCTAssertEqual(a1.workoutSessionId, s1.id)
        XCTAssertNotEqual(s1.id, s0.id)
        XCTAssertEqual(s1.linkedActivityId, a1.id)
    }
}
