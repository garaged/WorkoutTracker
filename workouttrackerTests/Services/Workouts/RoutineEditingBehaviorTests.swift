import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class RoutineEditingBehaviorTests: XCTestCase {

    func test_editingRoutineOnlyChangesFutureSessions_andKeepsExistingSessionSnapshots() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let bench = Exercise(name: "Bench Press")
        let row = Exercise(name: "Chest Supported Row")
        context.insert(bench)
        context.insert(row)

        let routine = WorkoutRoutine(name: "Upper A")
        context.insert(routine)

        let item = WorkoutRoutineItem(
            order: 0,
            routine: routine,
            exercise: bench,
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
        )
        context.insert(item)
        routine.items = [item]

        let plan = WorkoutSetPlan(
            order: 0,
            targetReps: 8,
            targetWeight: 80,
            weightUnit: .kg,
            targetRPE: 8,
            restSeconds: 120,
            routineItem: item
        )
        context.insert(plan)
        item.setPlans = [plan]
        try context.save()

        let firstActivity = Activity(
            title: "Upper A",
            startAt: start,
            endAt: start.addingTimeInterval(60 * 60),
            kind: .workout,
            workoutRoutineId: routine.id
        )
        context.insert(firstActivity)
        try context.save()

        let firstSession = try WorkoutSessionStarter.startOrResumeSession(
            for: firstActivity,
            context: context,
            now: start
        )

        XCTAssertEqual(firstSession.sourceRoutineNameSnapshot, "Upper A")
        XCTAssertEqual(orderedExerciseNames(in: firstSession), ["Bench Press"])
        XCTAssertEqual(firstSession.exercises.first?.setLogs.first?.targetReps, 8)

        routine.name = "Upper B"
        item.exercise = row
        plan.targetReps = 12
        plan.targetWeight = 60
        routine.updatedAt = start.addingTimeInterval(300)
        try context.save()

        XCTAssertEqual(firstSession.sourceRoutineNameSnapshot, "Upper A")
        XCTAssertEqual(orderedExerciseNames(in: firstSession), ["Bench Press"])
        XCTAssertEqual(firstSession.exercises.first?.setLogs.first?.targetReps, 8)
        XCTAssertEqual(firstSession.exercises.first?.setLogs.first?.targetWeight, 80)

        let secondStart = start.addingTimeInterval(24 * 60 * 60)
        let secondActivity = Activity(
            title: "Upper B",
            startAt: secondStart,
            endAt: secondStart.addingTimeInterval(60 * 60),
            kind: .workout,
            workoutRoutineId: routine.id
        )
        context.insert(secondActivity)
        try context.save()

        let secondSession = try WorkoutSessionStarter.startOrResumeSession(
            for: secondActivity,
            context: context,
            now: secondStart
        )

        XCTAssertEqual(secondSession.sourceRoutineNameSnapshot, "Upper B")
        XCTAssertEqual(orderedExerciseNames(in: secondSession), ["Chest Supported Row"])
        XCTAssertEqual(secondSession.exercises.first?.setLogs.first?.targetReps, 12)
        XCTAssertEqual(secondSession.exercises.first?.setLogs.first?.targetWeight, 60)
    }

    func test_reorderingRoutineItemsChangesFutureSessionOrder_only() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        let bench = Exercise(name: "Bench Press")
        let row = Exercise(name: "Barbell Row")
        context.insert(bench)
        context.insert(row)

        let routine = WorkoutRoutine(name: "Upper A")
        context.insert(routine)

        let firstItem = WorkoutRoutineItem(
            order: 0,
            routine: routine,
            exercise: bench,
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
        )
        let secondItem = WorkoutRoutineItem(
            order: 1,
            routine: routine,
            exercise: row,
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
        )
        context.insert(firstItem)
        context.insert(secondItem)
        routine.items = [firstItem, secondItem]

        let firstPlan = WorkoutSetPlan(
            order: 0,
            targetReps: 8,
            targetWeight: 80,
            weightUnit: .kg,
            targetRPE: nil,
            restSeconds: 120,
            routineItem: firstItem
        )
        let secondPlan = WorkoutSetPlan(
            order: 0,
            targetReps: 10,
            targetWeight: 70,
            weightUnit: .kg,
            targetRPE: nil,
            restSeconds: 120,
            routineItem: secondItem
        )
        context.insert(firstPlan)
        context.insert(secondPlan)
        firstItem.setPlans = [firstPlan]
        secondItem.setPlans = [secondPlan]
        try context.save()

        let firstActivity = Activity(
            title: routine.name,
            startAt: start,
            endAt: start.addingTimeInterval(60 * 60),
            kind: .workout,
            workoutRoutineId: routine.id
        )
        context.insert(firstActivity)
        try context.save()

        let firstSession = try WorkoutSessionStarter.startOrResumeSession(
            for: firstActivity,
            context: context,
            now: start
        )

        XCTAssertEqual(orderedExerciseNames(in: firstSession), ["Bench Press", "Barbell Row"])

        firstItem.order = 1
        secondItem.order = 0
        routine.updatedAt = start.addingTimeInterval(300)
        try context.save()

        XCTAssertEqual(orderedExerciseNames(in: firstSession), ["Bench Press", "Barbell Row"])

        let secondStart = start.addingTimeInterval(2 * 24 * 60 * 60)
        let secondActivity = Activity(
            title: routine.name,
            startAt: secondStart,
            endAt: secondStart.addingTimeInterval(60 * 60),
            kind: .workout,
            workoutRoutineId: routine.id
        )
        context.insert(secondActivity)
        try context.save()

        let secondSession = try WorkoutSessionStarter.startOrResumeSession(
            for: secondActivity,
            context: context,
            now: secondStart
        )

        XCTAssertEqual(orderedExerciseNames(in: secondSession), ["Barbell Row", "Bench Press"])
    }

    func test_attachingWarmUp_preservesExistingRoutineItems() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let bench = Exercise(name: "Bench Press")
        let bike = Exercise(name: "Bike")
        context.insert(bench)
        context.insert(bike)

        let main = WorkoutRoutine(name: "Upper A")
        let warmUp = WorkoutRoutine(name: "Warm-Up")
        context.insert(main)
        context.insert(warmUp)

        let mainItem = WorkoutRoutineItem(
            order: 0,
            routine: main,
            exercise: bench,
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
        )
        let mainPlan = WorkoutSetPlan(order: 0, targetReps: 8, targetWeight: 80, weightUnit: .kg, targetRPE: nil, restSeconds: 120, routineItem: mainItem)
        let warmItem = WorkoutRoutineItem(
            order: 0,
            routine: warmUp,
            exercise: bike,
            trackingStyleRaw: ExerciseTrackingStyle.timeOnly.rawValue
        )

        context.insert(mainItem)
        context.insert(mainPlan)
        context.insert(warmItem)
        main.items = [mainItem]
        mainItem.setPlans = [mainPlan]
        warmUp.items = [warmItem]
        try context.save()

        main.warmUpRoutine = warmUp
        main.updatedAt = Date()
        try context.save()

        let fetched = try fetchRoutine(id: main.id, context: context)
        XCTAssertEqual(fetched.warmUpRoutine?.id, warmUp.id)
        XCTAssertEqual(fetched.items.count, 1)
        XCTAssertEqual(fetched.items.first?.exercise?.name, "Bench Press")
        XCTAssertEqual(fetched.items.first?.setPlans.first?.targetReps, 8)
    }

    func test_attachingCoolDown_persistsWithoutChangingRoutineItems() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let bench = Exercise(name: "Bench Press")
        let walk = Exercise(name: "Walk")
        context.insert(bench)
        context.insert(walk)

        let main = WorkoutRoutine(name: "Upper A")
        let coolDown = WorkoutRoutine(name: "Cool-Down")
        context.insert(main)
        context.insert(coolDown)

        let mainItem = WorkoutRoutineItem(
            order: 0,
            routine: main,
            exercise: bench,
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
        )
        let coolItem = WorkoutRoutineItem(
            order: 0,
            routine: coolDown,
            exercise: walk,
            trackingStyleRaw: ExerciseTrackingStyle.timeOnly.rawValue
        )
        context.insert(mainItem)
        context.insert(coolItem)
        main.items = [mainItem]
        coolDown.items = [coolItem]
        try context.save()

        main.coolDownRoutine = coolDown
        main.updatedAt = Date()
        try context.save()

        let fetched = try fetchRoutine(id: main.id, context: context)
        XCTAssertEqual(fetched.coolDownRoutine?.id, coolDown.id)
        XCTAssertEqual(fetched.items.first?.exercise?.name, "Bench Press")
    }

    func test_replacingWarmUp_updatesLinkedRoutine() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let firstWarmUp = WorkoutRoutine(name: "Bike Warm-Up")
        let replacementWarmUp = WorkoutRoutine(name: "Band Warm-Up")
        let main = WorkoutRoutine(name: "Upper A")
        [firstWarmUp, replacementWarmUp, main].forEach(context.insert)
        main.warmUpRoutine = firstWarmUp
        try context.save()

        main.warmUpRoutine = replacementWarmUp
        main.updatedAt = Date()
        try context.save()

        let fetched = try fetchRoutine(id: main.id, context: context)
        XCTAssertEqual(fetched.warmUpRoutine?.name, "Band Warm-Up")
    }

    func test_clearingCoolDown_removesLinkedRoutine() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context

        let coolDown = WorkoutRoutine(name: "Walk")
        let main = WorkoutRoutine(name: "Upper A")
        [coolDown, main].forEach(context.insert)
        main.coolDownRoutine = coolDown
        try context.save()

        main.coolDownRoutine = nil
        main.updatedAt = Date()
        try context.save()

        let fetched = try fetchRoutine(id: main.id, context: context)
        XCTAssertNil(fetched.coolDownRoutine)
    }

    private func fetchRoutine(id: UUID, context: ModelContext) throws -> WorkoutRoutine {
        let descriptor = FetchDescriptor<WorkoutRoutine>(predicate: #Predicate { $0.id == id })
        return try XCTUnwrap(context.fetch(descriptor).first)
    }

    private func orderedExerciseNames(in session: WorkoutSession) -> [String] {
        session.exercises
            .sorted { $0.order < $1.order }
            .map(\.exerciseNameSnapshot)
    }
}
