import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class FreestyleWorkoutRecorderTests: XCTestCase {
    private func container() throws -> ModelContainer {
        let schema = Schema([
            TrackedActivitySession.self,
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            WorkoutSetLog.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    func testStartAndFinishPersistOneDurationOnlyExerciseWithoutInventedMetrics() throws {
        let store = try container()
        let context = ModelContext(store)
        let startedAt = Date(timeIntervalSince1970: 1_000)

        let session = try FreestyleWorkoutRecorder().start(
            sessionName: "Freestyle workout",
            genericExerciseName: "   ",
            at: startedAt,
            context: context
        )
        let exercise = try XCTUnwrap(session.exercises.first)
        try FreestyleWorkoutRecorder().finish(
            exercise,
            in: session,
            at: startedAt.addingTimeInterval(45),
            context: context
        )

        let reopened = ModelContext(store)
        let saved = try XCTUnwrap(try reopened.fetch(FetchDescriptor<WorkoutSession>()).first)
        let savedExercise = try XCTUnwrap(saved.exercises.first)
        XCTAssertEqual(saved.exercises.count, 1)
        XCTAssertEqual(saved.sourceRoutineNameSnapshot, "Freestyle workout")
        XCTAssertEqual(savedExercise.exerciseNameSnapshot, "Unnamed exercise")
        XCTAssertEqual(savedExercise.trackingStyle, .timeOnly)
        XCTAssertEqual(savedExercise.actualDurationSeconds, 45)
        XCTAssertNil(savedExercise.targetDurationSeconds)
        XCTAssertNil(savedExercise.actualDistance)
        XCTAssertTrue(savedExercise.setLogs.isEmpty)
    }

    func testStartRejectsAnotherActiveWorkoutWithoutCreatingAnything() throws {
        let store = try container()
        let context = ModelContext(store)
        let active = WorkoutSession()
        context.insert(active)
        try context.save()

        XCTAssertThrowsError(
            try FreestyleWorkoutRecorder().start(
                sessionName: "Freestyle workout",
                genericExerciseName: "Unnamed exercise",
                context: context
            )
        ) {
            XCTAssertEqual(
                $0 as? FreestyleWorkoutRecorder.RecordingError,
                .activeSessionConflict([active.id])
            )
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
    }

    func testFailedStartRollsBackTheNewSession() throws {
        enum Fault: Error { case disk }
        let store = try container()
        let context = ModelContext(store)
        let failing = FreestyleWorkoutRecorder(save: { _ in throw Fault.disk })

        XCTAssertThrowsError(
            try failing.start(
                sessionName: "Freestyle workout",
                genericExerciseName: "Unnamed exercise",
                context: context
            )
        )
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
    }
}
