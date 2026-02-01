// workouttrackerTests/History/WorkoutHistoryFilteringTests.swift
import XCTest
@testable import workouttracker

final class WorkoutHistoryFilteringTests: XCTestCase {

    func testFiltering_completedOnly_routine_exercise_search() {
        let exBench = UUID()
        let exSquat = UUID()

        func makeSession(name: String?, status: WorkoutSessionStatus, exercises: [(UUID, String)]) -> WorkoutSession {
            let s = WorkoutSession(startedAt: Date())
            s.sourceRoutineNameSnapshot = name
            s.status = status
            s.exercises = exercises.enumerated().map { idx, e in
                WorkoutSessionExercise(order: idx, exerciseId: e.0, exerciseNameSnapshot: e.1, session: s)
            }
            for ex in s.exercises { ex.session = s }
            return s
        }

        let a = makeSession(name: "Push Day", status: .completed, exercises: [(exBench, "Bench Press")])
        let b = makeSession(name: "Leg Day", status: .inProgress, exercises: [(exSquat, "Squat")])
        let c = makeSession(name: "Push Day", status: .completed, exercises: [(exSquat, "Incline DB Press")])

        let base = [a, b, c]

        // completedOnly
        let onlyCompleted = WorkoutHistoryFiltering.filteredSessions(
            sessions: base,
            completedOnly: true,
            routineFilterName: nil,
            exerciseFilterId: nil,
            allowExerciseFilter: true,
            searchText: ""
        )
        XCTAssertEqual(Set(onlyCompleted.map(\.id)), Set([a.id, c.id]))

        // routine filter
        let pushOnly = WorkoutHistoryFiltering.filteredSessions(
            sessions: base,
            completedOnly: false,
            routineFilterName: "Push Day",
            exerciseFilterId: nil,
            allowExerciseFilter: true,
            searchText: ""
        )
        XCTAssertEqual(Set(pushOnly.map(\.id)), Set([a.id, c.id]))

        // exercise filter (allowed)
        let benchOnly = WorkoutHistoryFiltering.filteredSessions(
            sessions: base,
            completedOnly: false,
            routineFilterName: nil,
            exerciseFilterId: exBench,
            allowExerciseFilter: true,
            searchText: ""
        )
        XCTAssertEqual(Set(benchOnly.map(\.id)), Set([a.id]))

        // search hits routine
        let searchRoutine = WorkoutHistoryFiltering.filteredSessions(
            sessions: base,
            completedOnly: false,
            routineFilterName: nil,
            exerciseFilterId: nil,
            allowExerciseFilter: true,
            searchText: "push"
        )
        XCTAssertEqual(Set(searchRoutine.map(\.id)), Set([a.id, c.id]))

        // search hits exercise name (case-insensitive + trimmed)
        let searchExercise = WorkoutHistoryFiltering.filteredSessions(
            sessions: base,
            completedOnly: false,
            routineFilterName: nil,
            exerciseFilterId: nil,
            allowExerciseFilter: true,
            searchText: "  BENCH "
        )
        XCTAssertEqual(Set(searchExercise.map(\.id)), Set([a.id]))
    }
}
