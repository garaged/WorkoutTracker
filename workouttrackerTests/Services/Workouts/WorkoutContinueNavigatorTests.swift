import XCTest
@testable import workouttracker

final class WorkoutContinueNavigatorTests: XCTestCase {

    func test_continue_prefersNextIncompleteInActiveExercise() {
        let ex1 = WorkoutSessionExercise(order: 0, exerciseId: UUID(), exerciseNameSnapshot: "A")

        let s1 = WorkoutSetLog(order: 0, origin: .added, reps: 10, weight: 100, weightUnit: .kg,
                              rpe: nil, completed: true, completedAt: nil,
                              targetReps: nil, targetWeight: nil, targetWeightUnit: .kg,
                              targetRPE: nil, targetRestSeconds: nil, sessionExercise: nil)

        let s2 = WorkoutSetLog(order: 1, origin: .added, reps: 10, weight: 100, weightUnit: .kg,
                              rpe: nil, completed: false, completedAt: nil,
                              targetReps: nil, targetWeight: nil, targetWeightUnit: .kg,
                              targetRPE: nil, targetRestSeconds: nil, sessionExercise: nil)

        let s3 = WorkoutSetLog(order: 2, origin: .added, reps: 10, weight: 100, weightUnit: .kg,
                              rpe: nil, completed: false, completedAt: nil,
                              targetReps: nil, targetWeight: nil, targetWeightUnit: .kg,
                              targetRPE: nil, targetRestSeconds: nil, sessionExercise: nil)

        ex1.setLogs = [s1, s2, s3]

        let ex2 = WorkoutSessionExercise(order: 1, exerciseId: UUID(), exerciseNameSnapshot: "B")
        let t1 = WorkoutSetLog(order: 0, origin: .added, reps: 8, weight: 60, weightUnit: .kg,
                              rpe: nil, completed: false, completedAt: nil,
                              targetReps: nil, targetWeight: nil, targetWeightUnit: .kg,
                              targetRPE: nil, targetRestSeconds: nil, sessionExercise: nil)
        ex2.setLogs = [t1]

        let nav = WorkoutContinueNavigator()

        let target = nav.nextTargetSetID(exercises: [ex1, ex2], activeExerciseID: ex1.id, activeSetID: s1.id)
        XCTAssertEqual(target, s2.id)
    }

    func test_continue_movesToNextExerciseWhenActiveExerciseHasNoIncomplete() {
        let ex1 = WorkoutSessionExercise(order: 0, exerciseId: UUID(), exerciseNameSnapshot: "A")
        let d1 = WorkoutSetLog(order: 0, origin: .added, reps: 10, weight: 100, weightUnit: .kg,
                              rpe: nil, completed: true, completedAt: nil,
                              targetReps: nil, targetWeight: nil, targetWeightUnit: .kg,
                              targetRPE: nil, targetRestSeconds: nil, sessionExercise: nil)
        ex1.setLogs = [d1]

        let ex2 = WorkoutSessionExercise(order: 1, exerciseId: UUID(), exerciseNameSnapshot: "B")
        let t1 = WorkoutSetLog(order: 0, origin: .added, reps: 8, weight: 60, weightUnit: .kg,
                              rpe: nil, completed: false, completedAt: nil,
                              targetReps: nil, targetWeight: nil, targetWeightUnit: .kg,
                              targetRPE: nil, targetRestSeconds: nil, sessionExercise: nil)
        ex2.setLogs = [t1]

        let nav = WorkoutContinueNavigator()
        let target = nav.nextTargetSetID(exercises: [ex1, ex2], activeExerciseID: ex1.id, activeSetID: d1.id)

        XCTAssertEqual(target, t1.id)
    }
}
