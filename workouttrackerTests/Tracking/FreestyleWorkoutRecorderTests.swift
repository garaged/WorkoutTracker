import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class FreestyleWorkoutRecorderTests: XCTestCase {
    private func container() throws -> ModelContainer {
        let schema = Schema([TrackedActivitySession.self, WorkoutSession.self,
                             WorkoutSessionExercise.self, WorkoutSetLog.self, Exercise.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    func testStartFinishAndNextPersistIndependentDurationOnlyIntervals() throws {
        let store = try container(), context = ModelContext(store)
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = try FreestyleWorkoutRecorder().start(
            sessionName: "Freestyle workout", genericExerciseName: "   ", at: startedAt, context: context)
        let first = try XCTUnwrap(session.exercises.first)
        try FreestyleWorkoutRecorder().finish(first, in: session, at: startedAt.addingTimeInterval(45), context: context)

        let catalog = Exercise(name: "Lat pulldown")
        context.insert(catalog)
        try context.save()
        let second = try FreestyleWorkoutRecorder().startNext(
            catalogExercise: catalog, genericExerciseName: "ignored", in: session,
            at: startedAt.addingTimeInterval(60), context: context)
        try FreestyleWorkoutRecorder().finish(second, in: session, at: startedAt.addingTimeInterval(90), context: context)

        let reopened = ModelContext(store)
        let saved = try XCTUnwrap(try reopened.fetch(FetchDescriptor<WorkoutSession>()).first)
        let exercises = saved.exercises.sorted { $0.order < $1.order }
        XCTAssertEqual(exercises.count, 2)
        XCTAssertEqual(exercises.map(\.order), [0, 1])
        XCTAssertNotEqual(exercises[0].id, exercises[1].id)
        XCTAssertEqual(exercises[0].exerciseNameSnapshot, "Unnamed exercise")
        XCTAssertEqual(exercises[0].actualDurationSeconds, 45)
        XCTAssertEqual(exercises[1].exerciseId, catalog.id)
        XCTAssertEqual(exercises[1].exerciseNameSnapshot, "Lat pulldown")
        XCTAssertEqual(exercises[1].actualDurationSeconds, 30)
        XCTAssertNotNil(exercises[0].freestyleStartedAt)
        XCTAssertNotNil(exercises[0].freestyleEndedAt)
        XCTAssertNotNil(exercises[1].freestyleStartedAt)
        XCTAssertNotNil(exercises[1].freestyleEndedAt)
        XCTAssertTrue(exercises.allSatisfy { $0.trackingStyle == .timeOnly && $0.setLogs.isEmpty })
    }

    func testFinishIsIdempotentAndNextRequiresFinishedExercise() throws {
        let store = try container(), context = ModelContext(store)
        let start = Date(timeIntervalSince1970: 1_000)
        let session = try FreestyleWorkoutRecorder().start(sessionName: "Freestyle", genericExerciseName: "Exercise", at: start, context: context)
        let exercise = try XCTUnwrap(session.exercises.first)
        XCTAssertThrowsError(try FreestyleWorkoutRecorder().startNext(catalogExercise: nil, genericExerciseName: "Next", in: session, context: context))
        try FreestyleWorkoutRecorder().finish(exercise, in: session, at: start.addingTimeInterval(45), context: context)
        try FreestyleWorkoutRecorder().finish(exercise, in: session, at: start.addingTimeInterval(75), context: context)
        XCTAssertEqual(exercise.actualDurationSeconds, 45)
        XCTAssertEqual(session.exercises.count, 1)
    }

    func testStartRejectsAnotherActiveWorkoutWithoutCreatingAnything() throws {
        let store = try container(), context = ModelContext(store), active = WorkoutSession()
        context.insert(active); try context.save()
        XCTAssertThrowsError(try FreestyleWorkoutRecorder().start(sessionName: "Freestyle", genericExerciseName: "Unnamed", context: context)) {
            XCTAssertEqual($0 as? FreestyleWorkoutRecorder.RecordingError, .activeSessionConflict([active.id]))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
    }

    func testFailedStartRollsBackTheNewSession() throws {
        enum Fault: Error { case disk }
        let store = try container(), context = ModelContext(store)
        XCTAssertThrowsError(try FreestyleWorkoutRecorder(save: { _ in throw Fault.disk }).start(
            sessionName: "Freestyle", genericExerciseName: "Unnamed", context: context))
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
    }
}
