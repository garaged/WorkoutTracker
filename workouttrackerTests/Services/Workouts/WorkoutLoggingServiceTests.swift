import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class WorkoutLoggingServiceTests: XCTestCase {

    private func makeSession(
        context: ModelContext,
        sets: [(reps: Int?, weight: Double?, completed: Bool)] = [
            (10, 100, false),
            (8, 110, false)
        ]
    ) throws -> (WorkoutSession, WorkoutSessionExercise, [WorkoutSetLog]) {
        let session = WorkoutSession(startedAt: Date())
        let ex = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Bench",
            session: session
        )

        session.exercises.append(ex)

        var logs: [WorkoutSetLog] = []
        for (idx, s) in sets.enumerated() {
            let log = WorkoutSetLog(
                order: idx,
                origin: .planned,
                reps: s.reps,
                weight: s.weight,
                completed: s.completed,
                sessionExercise: ex
            )
            logs.append(log)
            ex.setLogs.append(log)
        }

        context.insert(session)
        context.insert(ex)
        logs.forEach { context.insert($0) }
        try context.save()

        return (session, ex, logs)
    }

    func test_addSet_insertsAfter_andRenumbersOrders() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let (_, ex, logs) = try makeSession(context: context)

        let svc = WorkoutLoggingService()
        let newSet = svc.addSet(to: ex, after: logs[0], template: logs[0], context: context)
        XCTAssertNotNil(newSet)

        let ordered = ex.setLogs.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.map(\.order), [0, 1, 2])
        XCTAssertEqual(ordered[1].id, newSet!.id)
        XCTAssertEqual(ordered[1].reps, logs[0].reps)
        XCTAssertEqual(ordered[1].weight, logs[0].weight)
    }

    func test_copySet_insertsAfterSource_resetsCompletion() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let (_, ex, logs) = try makeSession(context: context)

        logs[0].completed = true
        logs[0].completedAt = Date()
        try context.save()

        let svc = WorkoutLoggingService()
        let copied = svc.copySet(logs[0], in: ex, context: context)
        XCTAssertNotNil(copied)

        let ordered = ex.setLogs.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.count, 3)

        // Copied set should be immediately after source
        XCTAssertEqual(ordered[1].id, copied!.id)

        // Copied values match, but completion is reset
        XCTAssertEqual(copied!.reps, logs[0].reps)
        XCTAssertEqual(copied!.weight, logs[0].weight)
        XCTAssertFalse(copied!.completed)
        XCTAssertNil(copied!.completedAt)
    }

    func test_deleteSet_thenUndo_restoresSetAndOrder() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let (_, ex, logs) = try makeSession(context: context)

        let svc = WorkoutLoggingService()

        svc.deleteSet(logs[1], from: ex, context: context)
        XCTAssertEqual(ex.setLogs.count, 1)
        XCTAssertEqual(ex.setLogs[0].order, 0)

        svc.undoLast(context: context)

        let ordered = ex.setLogs.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.count, 2)
        XCTAssertEqual(ordered.map(\.order), [0, 1])
        XCTAssertEqual(ordered[1].reps, logs[1].reps)
        XCTAssertEqual(ordered[1].weight, logs[1].weight)
    }

    func test_toggleCompleted_setsCompletedAt_andUndoRestores() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let (_, _, logs) = try makeSession(context: context)

        let svc = WorkoutLoggingService()

        XCTAssertFalse(logs[0].completed)
        XCTAssertNil(logs[0].completedAt)

        svc.toggleCompleted(logs[0], context: context)
        XCTAssertTrue(logs[0].completed)
        XCTAssertNotNil(logs[0].completedAt)

        svc.undoLast(context: context)
        XCTAssertFalse(logs[0].completed)
        XCTAssertNil(logs[0].completedAt)
    }

    func test_bumpReps_andUndo() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let (_, _, logs) = try makeSession(context: context, sets: [(nil, 100, false)])

        let svc = WorkoutLoggingService()

        svc.bumpReps(logs[0], delta: -1, context: context) // nil -> 0, clamp
        XCTAssertEqual(logs[0].reps, 0)

        svc.bumpReps(logs[0], delta: +2, context: context)
        XCTAssertEqual(logs[0].reps, 2)

        svc.undoLast(context: context) // undo +2
        XCTAssertEqual(logs[0].reps, 0)
    }
}
