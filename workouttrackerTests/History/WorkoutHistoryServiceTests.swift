// workouttrackerTests/History/WorkoutHistoryServiceTests.swift
import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class WorkoutHistoryServiceTests: XCTestCase {

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

    func testRecentSessions_sortedAndCompletionFilter() throws {
        let ctx = try makeContext()
        let svc = WorkoutHistoryService()

        let now = Date()
        let s0 = WorkoutSession(startedAt: now)
        s0.status = .inProgress

        let s1 = WorkoutSession(startedAt: now.addingTimeInterval(-3600))
        s1.status = .completed

        let s2 = WorkoutSession(startedAt: now.addingTimeInterval(-7200))
        s2.status = .completed

        try insert([s2, s0, s1], into: ctx)

        let all = try svc.recentSessions(limit: 10, includeIncomplete: true, context: ctx)
        XCTAssertEqual(all.map(\.id), [s0.id, s1.id, s2.id])

        let completedOnly = try svc.recentSessions(limit: 10, includeIncomplete: false, context: ctx)
        XCTAssertEqual(completedOnly.map(\.id), [s1.id, s2.id])
    }

    func testSessionsOnDay_respectsDayWindow() throws {
        let ctx = try makeContext()
        let cal = Calendar(identifier: .gregorian)
        let svc = WorkoutHistoryService(calendar: cal)

        let day = Date(timeIntervalSince1970: 1_700_000_000) // stable anchor
        let start = cal.startOfDay(for: day)

        let inside1 = WorkoutSession(startedAt: start.addingTimeInterval(9 * 3600))
        inside1.status = .completed

        let inside2 = WorkoutSession(startedAt: start.addingTimeInterval(23 * 3600))
        inside2.status = .completed

        let outside = WorkoutSession(startedAt: start.addingTimeInterval(26 * 3600)) // next day
        outside.status = .completed

        try insert([inside1, inside2, outside], into: ctx)

        let fetched = try svc.sessions(on: day, includeIncomplete: true, context: ctx)
        XCTAssertEqual(fetched.map(\.id), [inside2.id, inside1.id]) // reverse by startedAt
    }

    func testSessionsContainingExercise_filtersCorrectly() throws {
        let ctx = try makeContext()
        let svc = WorkoutHistoryService()

        let exId = UUID()

        func session(withExercise: Bool, at date: Date) -> WorkoutSession {
            let s = WorkoutSession(startedAt: date)
            s.status = .completed
            if withExercise {
                let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s)
                let log = WorkoutSetLog(order: 0, reps: 5, weight: 100, weightUnit: .kg, completed: true, completedAt: date)
                ex.setLogs = [log]
                s.exercises = [ex]
                ex.session = s
            }
            return s
        }

        let sA = session(withExercise: true, at: Date())
        let sB = session(withExercise: false, at: Date().addingTimeInterval(-3600))

        try insert([sA, sB], into: ctx)

        let fetched = try svc.sessions(containing: exId, limit: 10, includeIncomplete: true, context: ctx)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, sA.id)
    }

    func testExerciseTimeline_prefersE1RM_thenWeight_thenReps_andIsChronological() throws {
        let ctx = try makeContext()
        let svc = WorkoutHistoryService()

        let exId = UUID()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(86400)
        let t2 = t1.addingTimeInterval(86400)

        // Session 0: reps-only => label Reps
        let s0 = WorkoutSession(startedAt: t0); s0.status = .completed
        do {
            let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s0)
            let log = WorkoutSetLog(order: 0, reps: 12, weight: nil, weightUnit: .kg, completed: true, completedAt: t0)
            ex.setLogs = [log]
            s0.exercises = [ex]; ex.session = s0
        }

        // Session 1: has weight-only and weight+reps => label e1RM (preferred when possible)
        let s1 = WorkoutSession(startedAt: t1); s1.status = .completed
        do {
            let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s1)
            let wOnly = WorkoutSetLog(order: 0, reps: nil, weight: 200, weightUnit: .kg, completed: true, completedAt: t1)
            let wR = WorkoutSetLog(order: 1, reps: 5, weight: 100, weightUnit: .kg, completed: true, completedAt: t1)
            ex.setLogs = [wOnly, wR]
            s1.exercises = [ex]; ex.session = s1
        }

        // Session 2: weight-only => label Weight
        let s2 = WorkoutSession(startedAt: t2); s2.status = .completed
        do {
            let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s2)
            let log = WorkoutSetLog(order: 0, reps: nil, weight: 120, weightUnit: .kg, completed: true, completedAt: t2)
            ex.setLogs = [log]
            s2.exercises = [ex]; ex.session = s2
        }

        try insert([s2, s0, s1], into: ctx)

        let points = try svc.exerciseTimeline(exerciseId: exId, limit: 40, includeIncomplete: true, context: ctx)
        XCTAssertEqual(points.map(\.sessionId), [s0.id, s1.id, s2.id]) // oldest -> newest
        XCTAssertEqual(points.map(\.label), ["Reps", "e1RM", "Weight"])
    }
}
