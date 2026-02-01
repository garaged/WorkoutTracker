// workouttrackerTests/PR/PersonalRecordsServiceTests.swift
import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class PersonalRecordsServiceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            WorkoutSetLog.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private func insert(_ sessions: [WorkoutSession], into context: ModelContext) throws {
        for s in sessions {
            context.insert(s)
            for ex in s.exercises {
                context.insert(ex)
                for log in ex.setLogs {
                    context.insert(log)
                }
            }
        }
        try context.save()
    }

    func testRecordsAndTrend_useCompletedSessionsOnly() throws {
        let ctx = try makeContext()
        let svc = PersonalRecordsService()
        let exId = UUID()

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(86400)

        // Completed session: 100x5
        let s0 = WorkoutSession(startedAt: t0)
        s0.status = .completed
        do {
            let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s0)
            let log = WorkoutSetLog(order: 0, reps: 5, weight: 100, weightUnit: .kg, completed: true, completedAt: t0)
            ex.setLogs = [log]
            s0.exercises = [ex]; ex.session = s0
        }

        // Completed session: 110x4 (best weight 110)
        let s1 = WorkoutSession(startedAt: t1)
        s1.status = .completed
        do {
            let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s1)
            let log = WorkoutSetLog(order: 0, reps: 4, weight: 110, weightUnit: .kg, completed: true, completedAt: t1)
            ex.setLogs = [log]
            s1.exercises = [ex]; ex.session = s1
        }

        // In-progress session should be ignored
        let s2 = WorkoutSession(startedAt: t1.addingTimeInterval(3600))
        s2.status = .inProgress
        do {
            let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s2)
            let log = WorkoutSetLog(order: 0, reps: 20, weight: 500, weightUnit: .kg, completed: true, completedAt: t1)
            ex.setLogs = [log]
            s2.exercises = [ex]; ex.session = s2
        }

        try insert([s0, s1, s2], into: ctx)

        let records = try svc.records(for: exId, context: ctx)
        let bestWeight = try XCTUnwrap(records.bestWeight?.value, "Expected bestWeight to be present")
        XCTAssertEqual(bestWeight, 110, accuracy: 0.0001)

        let bestReps = try XCTUnwrap(records.bestReps?.value, "Expected bestReps to be present")
        XCTAssertEqual(bestReps, 5)


        let trend = try svc.trend(for: exId, limit: 10, context: ctx)
        XCTAssertEqual(trend.map(\.id), [s0.id, s1.id]) // chronological
    }

    func testNextTargetText_prefersWeightAndUsesUnitIncrement() throws {
        let ctx = try makeContext()
        let svc = PersonalRecordsService()
        let exId = UUID()

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        let s0 = WorkoutSession(startedAt: t0)
        s0.status = .completed
        do {
            let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s0)
            let log = WorkoutSetLog(order: 0, reps: 5, weight: 100, weightUnit: .kg, completed: true, completedAt: t0)
            ex.setLogs = [log]
            s0.exercises = [ex]; ex.session = s0
        }

        try insert([s0], into: ctx)

        let records = try svc.records(for: exId, context: ctx)
        let txt = try svc.nextTargetText(for: exId, records: records, context: ctx)
        XCTAssertNotNil(txt)
        XCTAssertTrue(txt!.contains("+2.5"))
        XCTAssertTrue(txt!.lowercased().contains("kg"))
    }
}
