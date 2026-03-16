import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class LinkedRoutineSessionFlowTests: XCTestCase {

    func test_startOrResumeSession_withLinkedWarmUpAndCoolDown_buildsExecutionChainInOrder() throws {
        let context = try makeInMemoryContext()
        let mainRoutine = try makeLinkedStrengthRoutine(context: context)

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let activity = Activity(
            title: mainRoutine.name,
            startAt: start,
            endAt: start.addingTimeInterval(60 * 60),
            kind: .workout,
            workoutRoutineId: mainRoutine.id
        )
        context.insert(activity)
        try context.save()

        let session = try WorkoutSessionStarter.startOrResumeSession(
            for: activity,
            context: context,
            now: start
        )

        XCTAssertEqual(session.exercises.count, 3)
        XCTAssertEqual(
            session.exercises.sorted { $0.order < $1.order }.map(\.segment),
            [.warmUp, .main, .coolDown]
        )
        XCTAssertEqual(session.exercises.sorted { $0.order < $1.order }.map(\.exerciseNameSnapshot), [
            "Warm-up Press",
            "Main Bench",
            "Cool-down Press"
        ])
    }

    func test_startOrResumeSession_withoutLinks_preservesMainOnlyBehavior() throws {
        let context = try makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press")
        let routine = WorkoutRoutine(name: "Upper A")
        let item = WorkoutRoutineItem(order: 0, routine: routine, exercise: exercise, trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue)
        let plan = WorkoutSetPlan(order: 0, targetReps: 8, targetWeight: 80, weightUnit: .kg, targetRPE: nil, restSeconds: 90, routineItem: item)

        routine.items = [item]
        item.setPlans = [plan]

        context.insert(exercise)
        context.insert(routine)
        context.insert(item)
        context.insert(plan)
        try context.save()

        let start = Date(timeIntervalSince1970: 1_810_000_000)
        let activity = Activity(
            title: routine.name,
            startAt: start,
            endAt: start.addingTimeInterval(60 * 60),
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

        XCTAssertEqual(session.exercises.count, 1)
        XCTAssertEqual(session.exercises.first?.segment, .main)
        XCTAssertEqual(session.exercises.first?.exerciseNameSnapshot, "Bench Press")
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

    private func makeLinkedStrengthRoutine(context: ModelContext) throws -> WorkoutRoutine {
        let warmExercise = Exercise(name: "Warm-up Press")
        let mainExercise = Exercise(name: "Main Bench")
        let coolExercise = Exercise(name: "Cool-down Press")

        let warmRoutine = WorkoutRoutine(name: "Warm-up")
        let mainRoutine = WorkoutRoutine(name: "Main")
        let coolRoutine = WorkoutRoutine(name: "Cool-down")

        let warmItem = WorkoutRoutineItem(order: 0, routine: warmRoutine, exercise: warmExercise, trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue)
        let mainItem = WorkoutRoutineItem(order: 0, routine: mainRoutine, exercise: mainExercise, trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue)
        let coolItem = WorkoutRoutineItem(order: 0, routine: coolRoutine, exercise: coolExercise, trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue)

        let warmPlan = WorkoutSetPlan(order: 0, targetReps: 12, targetWeight: 20, weightUnit: .kg, targetRPE: nil, restSeconds: 30, routineItem: warmItem)
        let mainPlan = WorkoutSetPlan(order: 0, targetReps: 5, targetWeight: 60, weightUnit: .kg, targetRPE: nil, restSeconds: 60, routineItem: mainItem)
        let coolPlan = WorkoutSetPlan(order: 0, targetReps: 10, targetWeight: 15, weightUnit: .kg, targetRPE: nil, restSeconds: 30, routineItem: coolItem)

        warmRoutine.items = [warmItem]
        mainRoutine.items = [mainItem]
        coolRoutine.items = [coolItem]

        warmItem.setPlans = [warmPlan]
        mainItem.setPlans = [mainPlan]
        coolItem.setPlans = [coolPlan]

        mainRoutine.warmUpRoutine = warmRoutine
        mainRoutine.coolDownRoutine = coolRoutine

        context.insert(warmExercise)
        context.insert(mainExercise)
        context.insert(coolExercise)
        context.insert(warmRoutine)
        context.insert(mainRoutine)
        context.insert(coolRoutine)
        context.insert(warmItem)
        context.insert(mainItem)
        context.insert(coolItem)
        context.insert(warmPlan)
        context.insert(mainPlan)
        context.insert(coolPlan)
        try context.save()

        return mainRoutine
    }
}
