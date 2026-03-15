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
        XCTAssertEqual(exerciseTemplate.segment, .main)
        XCTAssertEqual(exerciseTemplate.sets.count, 1)

        let set = try XCTUnwrap(setsOrFirst(from: exerciseTemplate))
        XCTAssertNil(set.targetReps)
        XCTAssertNil(set.targetWeight)
        XCTAssertNil(set.targetRPE)

        let duration = try XCTUnwrap(set.targetDurationSeconds)
        XCTAssertEqual(duration, 30 * 60)

        let distance = try XCTUnwrap(set.targetDistance)
        XCTAssertEqual(distance, 3.25, accuracy: 0.000_1)
    }

    func test_toExecutionSegments_buildsWarmUpMainCoolDownChainInOrder() throws {
        let context = try makeInMemoryContext()

        let warmUpExercise = Exercise(name: "Bike")
        let mainExercise = Exercise(name: "Bench Press")
        let coolDownExercise = Exercise(name: "Walk")

        let warmUp = WorkoutRoutine(name: "Warm-Up")
        let main = WorkoutRoutine(name: "Push Day")
        let coolDown = WorkoutRoutine(name: "Cool-Down")

        let warmItem = WorkoutRoutineItem(
            order: 0,
            routine: warmUp,
            exercise: warmUpExercise,
            trackingStyleRaw: ExerciseTrackingStyle.timeOnly.rawValue
        )
        let mainItem = WorkoutRoutineItem(
            order: 0,
            routine: main,
            exercise: mainExercise,
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
        )
        let coolItem = WorkoutRoutineItem(
            order: 0,
            routine: coolDown,
            exercise: coolDownExercise,
            trackingStyleRaw: ExerciseTrackingStyle.timeOnly.rawValue
        )

        warmUp.items = [warmItem]
        main.items = [mainItem]
        coolDown.items = [coolItem]
        main.warmUpRoutine = warmUp
        main.coolDownRoutine = coolDown

        [warmUpExercise, mainExercise, coolDownExercise].forEach { context.insert($0) }
        [warmUp, main, coolDown].forEach { context.insert($0) }
        [warmItem, mainItem, coolItem].forEach { context.insert($0) }
        try context.save()

        let segments = WorkoutRoutineMapper.toExecutionSegments(routine: main)

        XCTAssertEqual(segments.map(\.kind), [.warmUp, .main, .coolDown])
        XCTAssertEqual(segments.map(\.routineName), ["Warm-Up", "Push Day", "Cool-Down"])
        XCTAssertEqual(segments.flatMap(\.exerciseItems).compactMap { $0.exercise?.name }, ["Bike", "Bench Press", "Walk"])

        let flattened = WorkoutRoutineMapper.toExerciseTemplates(executionSegments: segments)
        XCTAssertEqual(flattened.map(\.segment), [.warmUp, .main, .coolDown])
        XCTAssertEqual(flattened.map(\.nameSnapshot), ["Bike", "Bench Press", "Walk"])
        XCTAssertEqual(flattened.map(\.order), [0, 1, 2])
    }

    func test_toExerciseTemplates_preservesRoutineItemSegment() throws {
        let context = try makeInMemoryContext()
        let (_, routine, _, _) = try makeWalkingRoutine(
            context: context,
            durationSeconds: 10 * 60,
            distance: 1.2,
            segment: .warmUp
        )

        let templates = WorkoutRoutineMapper.toExerciseTemplates(routine: routine)
        let template = try XCTUnwrap(templates.first)

        XCTAssertEqual(template.segment, .warmUp)
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
        XCTAssertEqual(session.exercises.first?.segment, .main)
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

    func test_startOrResumeSession_persistsRoutineItemSegmentIntoSessionExercise() throws {
        let context = try makeInMemoryContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let (_, routine, _, _) = try makeWalkingRoutine(
            context: context,
            durationSeconds: 12 * 60,
            distance: 1.5,
            segment: .coolDown
        )

        let activity = Activity(
            title: "Cool Down Walk",
            startAt: start,
            endAt: start.addingTimeInterval(12 * 60),
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

        XCTAssertEqual(session.exercises.first?.segment, .coolDown)
    }

    func test_startOrResumeSession_includesLinkedSegments_andPersistsSegment() throws {
        let context = try makeInMemoryContext()
        let start = Date(timeIntervalSince1970: 1_700_000_500)

        let warmUpExercise = Exercise(name: "Bike")
        let mainExercise = Exercise(name: "Bench Press")
        let coolDownExercise = Exercise(name: "Walk")

        let warmUp = WorkoutRoutine(name: "Warm-Up")
        let main = WorkoutRoutine(name: "Push Day")
        let coolDown = WorkoutRoutine(name: "Cool-Down")

        let warmItem = WorkoutRoutineItem(
            order: 0,
            routine: warmUp,
            exercise: warmUpExercise,
            trackingStyleRaw: ExerciseTrackingStyle.timeOnly.rawValue
        )
        let mainItem = WorkoutRoutineItem(
            order: 0,
            routine: main,
            exercise: mainExercise,
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
        )
        let coolItem = WorkoutRoutineItem(
            order: 0,
            routine: coolDown,
            exercise: coolDownExercise,
            trackingStyleRaw: ExerciseTrackingStyle.timeOnly.rawValue
        )

        let warmPlan = WorkoutSetPlan(
            order: 0,
            targetReps: nil,
            targetWeight: nil,
            weightUnit: .kg,
            targetDurationSeconds: 5 * 60,
            targetDistance: nil,
            targetRPE: nil,
            restSeconds: nil,
            routineItem: warmItem
        )
        let mainPlan = WorkoutSetPlan(
            order: 0,
            targetReps: 5,
            targetWeight: 100,
            weightUnit: .kg,
            targetRPE: 8,
            restSeconds: 180,
            routineItem: mainItem
        )
        let coolPlan = WorkoutSetPlan(
            order: 0,
            targetReps: nil,
            targetWeight: nil,
            weightUnit: .kg,
            targetDurationSeconds: 8 * 60,
            targetDistance: 1.0,
            targetRPE: nil,
            restSeconds: nil,
            routineItem: coolItem
        )

        warmUp.items = [warmItem]
        main.items = [mainItem]
        coolDown.items = [coolItem]
        warmItem.setPlans = [warmPlan]
        mainItem.setPlans = [mainPlan]
        coolItem.setPlans = [coolPlan]
        main.warmUpRoutine = warmUp
        main.coolDownRoutine = coolDown

        [warmUpExercise, mainExercise, coolDownExercise].forEach { context.insert($0) }
        [warmUp, main, coolDown].forEach { context.insert($0) }
        [warmItem, mainItem, coolItem].forEach { context.insert($0) }
        [warmPlan, mainPlan, coolPlan].forEach { context.insert($0) }

        let activity = Activity(
            title: "Push Session",
            startAt: start,
            endAt: start.addingTimeInterval(60 * 60),
            kind: .workout,
            workoutRoutineId: main.id
        )
        context.insert(activity)
        try context.save()

        let session = try WorkoutSessionStarter.startOrResumeSession(
            for: activity,
            context: context,
            now: start
        )

        XCTAssertEqual(session.exercises.map(\.exerciseNameSnapshot), ["Bike", "Bench Press", "Walk"])
        XCTAssertEqual(session.exercises.map(\.segment), [.warmUp, .main, .coolDown])
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
        distance: Double,
        segment: WorkoutExerciseSegment = .main
    ) throws -> (Exercise, WorkoutRoutine, WorkoutRoutineItem, WorkoutSetPlan) {
        let exercise = Exercise(name: "Walking", modality: .cardio)
        let routine = WorkoutRoutine(name: "Neighborhood Walk")
        let item = WorkoutRoutineItem(
            order: 0,
            routine: routine,
            exercise: exercise,
            trackingStyleRaw: ExerciseTrackingStyle.timeDistance.rawValue,
            segmentRaw: segment.rawValue
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

    private func setsOrFirst(from template: WorkoutExerciseTemplate) -> WorkoutExerciseTemplate.SetTemplate {
        template.sets[0]
    }
}
