// workouttrackerTests/Sessions/WorkoutSessionCompareServiceTests.swift
import XCTest
@testable import workouttracker

@MainActor
final class WorkoutSessionCompareServiceTests: XCTestCase {

    func testStats_volume_bestSet_duration_completedOnly() {
        let s = WorkoutSession(startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        s.endedAt = s.startedAt.addingTimeInterval(30 * 60) // 30m
        s.status = .completed

        let exId = UUID()
        let ex = WorkoutSessionExercise(order: 0, exerciseId: exId, exerciseNameSnapshot: "Bench", session: s)

        // completed: 100x5 (500)
        let a = WorkoutSetLog(order: 0, reps: 5, weight: 100, weightUnit: .kg, completed: true, completedAt: s.startedAt)
        // completed: 90x10 (900) => best set by volume
        let b = WorkoutSetLog(order: 1, reps: 10, weight: 90, weightUnit: .kg, completed: true, completedAt: s.startedAt)
        // NOT completed: 200x1 (ignored)
        let c = WorkoutSetLog(order: 2, reps: 1, weight: 200, weightUnit: .kg, completed: false, completedAt: nil)

        ex.setLogs = [a, b, c]
        s.exercises = [ex]
        ex.session = s

        let st = WorkoutSessionCompareService.stats(for: s, preferredUnit: .kg)

        XCTAssertEqual(st.exerciseCount, 1)
        XCTAssertEqual(st.completedSets, 2)
        XCTAssertEqual(st.volume, 1400, accuracy: 0.0001)
        XCTAssertEqual(st.durationSeconds, 30 * 60)
        XCTAssertEqual(st.durationText, "30m")

        // Best set should be the 90x10 one (900 volume).
        XCTAssertNotNil(st.bestSetText)
        XCTAssertTrue(st.bestSetText!.contains("kg"))
        XCTAssertTrue(st.bestSetText!.contains("× 10"))
    }

    func testStats_nilEndedAt_hasNoDurationText() {
        let s = WorkoutSession(startedAt: Date())
        s.endedAt = nil
        s.status = .completed

        let st = WorkoutSessionCompareService.stats(for: s, preferredUnit: .kg)
        XCTAssertEqual(st.durationSeconds, 0)
        XCTAssertNil(st.durationText)
    }
}
