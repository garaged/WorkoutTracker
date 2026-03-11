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

    private func orderedExerciseNames(in session: WorkoutSession) -> [String] {
        session.exercises
            .sorted { $0.order < $1.order }
            .map(\.exerciseNameSnapshot)
    }
}
