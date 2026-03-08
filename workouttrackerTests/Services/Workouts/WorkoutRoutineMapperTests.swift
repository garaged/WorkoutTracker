import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class WorkoutRoutineMapperTests: XCTestCase {

    func test_toExerciseTemplates_preservesTimeDistanceTargets_andDoesNotInventStrengthMetrics() throws {
        let context = try makeInMemoryContext()
        let (_, routine, _, _) = try makeWalkingRoutine(
            context: context,
            durationSeconds: 30 * 60,
            distance: 3.25
        )

        let templates = WorkoutRoutineMapper.toExerciseTemplates(routine: routine)

        XCTAssertEqual(templates.count, 1)

        let exerciseTemplate = try XCTUnwrap(templates.first)
        XCTAssertEqual(exerciseTemplate.nameSnapshot, "Walking")
        XCTAssertEqual(exerciseTemplate.sets.count, 1)

        let set = try XCTUnwrap(exerciseTemplate.sets.first)
        XCTAssertNil(set.targetReps)
        XCTAssertNil(set.targetWeight)
        XCTAssertNil(set.targetRPE)

        let duration = try XCTUnwrap(set.targetDurationSeconds)
        XCTAssertEqual(duration, 30 * 60)

        let distance = try XCTUnwrap(set.targetDistance)
        XCTAssertEqual(distance, 3.25, accuracy: 0.000_1)
    }

    func test_startOrResumeSession_copiesTimeDistanceTargetsIntoSessionLogs() throws {
        let context = try makeInMemoryContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let (_, routine, _, _) = try makeWalkingRoutine(
            context: context,
            durationSeconds: 25 * 60,
            distance: 2.4
        )

        let activity = Activity(
            title: "Lunch Walk",
            startAt: start,
            endAt: start.addingTimeInterval(25 * 60),
            kind: .workout,
            workoutRoutineId: routine.id
        )
        context.insert(activity)
        try context.save()

        let session = try WorkoutSessionStarter.startOrResumeSession(
            for: activity,
            context: context,
            now: start
        )
        
        XCTAssertEqual(session.exercises.first?.trackingStyle, .timeDistance)
        XCTAssertEqual(session.linkedActivityId, activity.id)
        XCTAssertEqual(session.sourceRoutineId, routine.id)
        XCTAssertEqual(activity.workoutSessionId, session.id)
        XCTAssertEqual(session.exercises.count, 1)

        let sessionExercise = try XCTUnwrap(session.exercises.first)
        XCTAssertEqual(sessionExercise.trackingStyle, .timeDistance)
        XCTAssertEqual(sessionExercise.exerciseNameSnapshot, "Walking")
        XCTAssertEqual(sessionExercise.setLogs.count, 1)

        let log = try XCTUnwrap(sessionExercise.setLogs.first)

        XCTAssertNil(log.targetReps)
        XCTAssertNil(log.targetWeight)
        XCTAssertNil(log.reps)
        XCTAssertNil(log.weight)

        let targetDuration = try XCTUnwrap(log.targetDurationSeconds)
        XCTAssertEqual(targetDuration, 25 * 60)

        let actualDuration = try XCTUnwrap(log.actualDurationSeconds)
        XCTAssertEqual(actualDuration, 25 * 60)

        let targetDistance = try XCTUnwrap(log.targetDistance)
        XCTAssertEqual(targetDistance, 2.4, accuracy: 0.000_1)

        let actualDistance = try XCTUnwrap(log.actualDistance)
        XCTAssertEqual(actualDistance, 2.4, accuracy: 0.000_1)
    }

    // MARK: - Helpers

    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Activity.self,
            Exercise.self,
            WorkoutRoutine.self,
            WorkoutRoutineItem.self,
            WorkoutSetPlan.self,
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            WorkoutSetLog.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeWalkingRoutine(
        context: ModelContext,
        durationSeconds: Int,
        distance: Double
    ) throws -> (Exercise, WorkoutRoutine, WorkoutRoutineItem, WorkoutSetPlan) {
        let exercise = Exercise(name: "Walking", modality: .cardio)
        let routine = WorkoutRoutine(name: "Neighborhood Walk")
        let item = WorkoutRoutineItem(
            order: 0,
            routine: routine,
            exercise: exercise,
            trackingStyleRaw: ExerciseTrackingStyle.timeDistance.rawValue
        )
        let plan = WorkoutSetPlan(
            order: 0,
            targetReps: nil,
            targetWeight: nil,
            weightUnit: .kg,
            targetDurationSeconds: durationSeconds,
            targetDistance: distance,
            targetRPE: nil,
            restSeconds: nil,
            routineItem: item
        )

        routine.items = [item]
        item.setPlans = [plan]

        context.insert(exercise)
        context.insert(routine)
        context.insert(item)
        context.insert(plan)
        try context.save()

        return (exercise, routine, item, plan)
    }
}
