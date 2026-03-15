import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class AnalyticsHistoryAdapterTests: XCTestCase {

    func test_loadExercisePerformanceSamples_mapsCompletedLogs_preservesSegment_andComputesActualRest() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let adapter = AnalyticsHistoryAdapter()

        let exerciseID = UUID()
        let startedAt = TestSupport.date(2026, 3, 1, 7, 0)

        let session = WorkoutSession(startedAt: startedAt)
        session.status = .completed
        session.endedAt = startedAt.addingTimeInterval(1_800)

        let exercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: exerciseID,
            exerciseNameSnapshot: "Bench Press",
            trackingStyle: .strength,
            segment: .main,
            session: session
        )

        let firstCompletedAt = startedAt.addingTimeInterval(60)
        let secondCompletedAt = startedAt.addingTimeInterval(180)

        exercise.setLogs = [
            WorkoutSetLog(
                order: 0,
                origin: .planned,
                reps: 5,
                weight: 100,
                weightUnit: .kg,
                completed: true,
                completedAt: firstCompletedAt,
                targetReps: 5,
                targetWeight: 100,
                targetWeightUnit: .kg,
                targetRestSeconds: 120
            ),
            WorkoutSetLog(
                order: 1,
                origin: .planned,
                reps: 4,
                weight: 110,
                weightUnit: .kg,
                completed: true,
                completedAt: secondCompletedAt,
                targetReps: 4,
                targetWeight: 110,
                targetWeightUnit: .kg,
                targetRestSeconds: 120
            )
        ]

        session.exercises = [exercise]
        try insert([session], into: context)

        let samples = try adapter.loadExercisePerformanceSamples(
            for: exerciseID,
            includeIncompleteSessions: false,
            context: context
        )

        XCTAssertEqual(samples.count, 2)

        let first = try XCTUnwrap(samples.first)
        XCTAssertEqual(first.exerciseID, exerciseID)
        XCTAssertEqual(first.exerciseName, "Bench Press")
        XCTAssertEqual(first.sessionID, session.id)
        XCTAssertEqual(first.sessionStartedAt, startedAt)
        XCTAssertEqual(first.segment, .main)
        XCTAssertEqual(try XCTUnwrap(first.weight), 100, accuracy: 0.0001)
        XCTAssertEqual(first.reps, 5)
        XCTAssertTrue(first.isCompleted)
        XCTAssertEqual(first.plannedRestSeconds, 120)
        XCTAssertNil(first.actualRestSeconds)

        let second = try XCTUnwrap(samples.last)
        XCTAssertEqual(second.segment, .main)
        XCTAssertEqual(try XCTUnwrap(second.weight), 110, accuracy: 0.0001)
        XCTAssertEqual(second.reps, 4)
        XCTAssertEqual(second.plannedRestSeconds, 120)
        XCTAssertEqual(second.actualRestSeconds, 120)
    }

    func test_loadExercisePerformanceSamples_excludesIncompleteSessionsByDefault_andCanIncludeThemWhenRequested() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let adapter = AnalyticsHistoryAdapter()

        let exerciseID = UUID()
        let completedStart = TestSupport.date(2026, 3, 2, 7, 0)
        let inProgressStart = TestSupport.date(2026, 3, 3, 7, 0)

        let completed = WorkoutSession(startedAt: completedStart)
        completed.status = .completed
        let completedExercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: exerciseID,
            exerciseNameSnapshot: "Squat",
            trackingStyle: .strength,
            segment: .main,
            session: completed
        )
        completedExercise.setLogs = [
            WorkoutSetLog(
                order: 0,
                reps: 5,
                weight: 140,
                weightUnit: .kg,
                completed: true,
                completedAt: completedStart.addingTimeInterval(60)
            )
        ]
        completed.exercises = [completedExercise]

        let inProgress = WorkoutSession(startedAt: inProgressStart)
        inProgress.status = .inProgress
        let inProgressExercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: exerciseID,
            exerciseNameSnapshot: "Squat",
            trackingStyle: .strength,
            segment: .main,
            session: inProgress
        )
        inProgressExercise.setLogs = [
            WorkoutSetLog(
                order: 0,
                reps: 3,
                weight: 150,
                weightUnit: .kg,
                completed: false,
                completedAt: nil
            )
        ]
        inProgress.exercises = [inProgressExercise]

        try insert([completed, inProgress], into: context)

        let defaultSamples = try adapter.loadExercisePerformanceSamples(
            for: exerciseID,
            includeIncompleteSessions: false,
            context: context
        )
        XCTAssertEqual(defaultSamples.count, 1)
        XCTAssertEqual(defaultSamples[0].sessionID, completed.id)

        let inclusiveSamples = try adapter.loadExercisePerformanceSamples(
            for: exerciseID,
            includeIncompleteSessions: true,
            context: context
        )
        XCTAssertEqual(inclusiveSamples.count, 2)
        XCTAssertEqual(Set(inclusiveSamples.map(\.sessionID)), Set([completed.id, inProgress.id]))
    }

    func test_loadCompletedSessionSamples_mapsCompletionState_completedExerciseCount_andSegmentsPresent() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let adapter = AnalyticsHistoryAdapter()

        let startedAt = TestSupport.date(2026, 3, 4, 7, 0)

        let session = WorkoutSession(startedAt: startedAt)
        session.status = .completed
        session.endedAt = startedAt.addingTimeInterval(1_800)

        let warmUp = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Band Pull-Apart",
            trackingStyle: .strength,
            segment: .warmUp,
            session: session
        )
        warmUp.setLogs = [
            WorkoutSetLog(
                order: 0,
                reps: 20,
                weight: nil,
                completed: true,
                completedAt: startedAt.addingTimeInterval(30)
            )
        ]

        let main = WorkoutSessionExercise(
            order: 1,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Bench Press",
            trackingStyle: .strength,
            segment: .main,
            session: session
        )
        main.setLogs = [
            WorkoutSetLog(
                order: 0,
                reps: 5,
                weight: 100,
                weightUnit: .kg,
                completed: true,
                completedAt: startedAt.addingTimeInterval(120)
            )
        ]

        let coolDown = WorkoutSessionExercise(
            order: 2,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Stretch",
            trackingStyle: .strength,
            segment: .coolDown,
            session: session
        )
        coolDown.setLogs = [
            WorkoutSetLog(
                order: 0,
                reps: nil,
                weight: nil,
                completed: false,
                completedAt: nil
            )
        ]

        session.exercises = [warmUp, main, coolDown]
        try insert([session], into: context)

        let samples = try adapter.loadSessionAnalyticsSamples(window: nil, context: context)

        XCTAssertEqual(samples.count, 1)

        let summary = try XCTUnwrap(samples.first)
        XCTAssertEqual(summary.id, session.id)
        XCTAssertEqual(summary.startedAt, startedAt)
        XCTAssertTrue(summary.wasCompleted)
        XCTAssertEqual(summary.completedExerciseCount, 2)
        XCTAssertEqual(summary.segmentsPresent, Set([.warmUp, .main, .coolDown]))
        XCTAssertEqual(summary.endedAt, startedAt.addingTimeInterval(1_800))
        XCTAssertEqual(summary.durationSeconds, 1_800)
    }

    func test_loadCompletedSessionSamples_respectsWindowUsingStartedAt() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let adapter = AnalyticsHistoryAdapter()

        let inWindowStart = TestSupport.date(2026, 3, 10, 7, 0)
        let outOfWindowStart = TestSupport.date(2026, 2, 20, 7, 0)

        let inWindow = WorkoutSession(startedAt: inWindowStart)
        inWindow.status = .completed
        let inWindowExercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Row",
            trackingStyle: .strength,
            segment: .main,
            session: inWindow
        )
        inWindowExercise.setLogs = [
            WorkoutSetLog(order: 0, reps: 10, weight: 60, weightUnit: .kg, completed: true, completedAt: inWindowStart.addingTimeInterval(60))
        ]
        inWindow.exercises = [inWindowExercise]

        let outOfWindow = WorkoutSession(startedAt: outOfWindowStart)
        outOfWindow.status = .completed
        let outOfWindowExercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Row",
            trackingStyle: .strength,
            segment: .main,
            session: outOfWindow
        )
        outOfWindowExercise.setLogs = [
            WorkoutSetLog(order: 0, reps: 8, weight: 70, weightUnit: .kg, completed: true, completedAt: outOfWindowStart.addingTimeInterval(60))
        ]
        outOfWindow.exercises = [outOfWindowExercise]

        try insert([inWindow, outOfWindow], into: context)

        let window = DateInterval(
            start: TestSupport.date(2026, 3, 1, 0, 0),
            end: TestSupport.date(2026, 3, 31, 23, 59)
        )

        let samples = try adapter.loadSessionAnalyticsSamples(window: window, context: context)

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.id, inWindow.id)
    }

    // MARK: - Helpers

    private func insert(_ sessions: [WorkoutSession], into context: ModelContext) throws {
        for session in sessions {
            context.insert(session)
        }
        try context.save()
    }
}
