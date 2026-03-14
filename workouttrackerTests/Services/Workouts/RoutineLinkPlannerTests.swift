import XCTest
@testable import workouttracker

@MainActor
final class RoutineLinkPlannerTests: XCTestCase {

    func test_buildExecutionSegments_withNoLinkedRoutines_returnsMainOnly() {
        let main = makeRoutine(named: "Main", exerciseName: "Bench Press")

        let segments = RoutineLinkPlanner.buildExecutionSegments(for: main)

        XCTAssertEqual(segments.map(\.kind), [.main])
        XCTAssertEqual(segments.map(\.routineName), ["Main"])
    }

    func test_buildExecutionSegments_withWarmUpOnly_returnsWarmUpThenMain() {
        let warmUp = makeRoutine(named: "Warm-Up", exerciseName: "Bike")
        let main = makeRoutine(named: "Main", exerciseName: "Bench Press")
        main.warmUpRoutine = warmUp

        let segments = RoutineLinkPlanner.buildExecutionSegments(for: main)

        XCTAssertEqual(segments.map(\.kind), [.warmUp, .main])
        XCTAssertEqual(segments.map(\.routineName), ["Warm-Up", "Main"])
    }

    func test_buildExecutionSegments_withCoolDownOnly_returnsMainThenCoolDown() {
        let main = makeRoutine(named: "Main", exerciseName: "Bench Press")
        let coolDown = makeRoutine(named: "Cool-Down", exerciseName: "Walk")
        main.coolDownRoutine = coolDown

        let segments = RoutineLinkPlanner.buildExecutionSegments(for: main)

        XCTAssertEqual(segments.map(\.kind), [.main, .coolDown])
        XCTAssertEqual(segments.map(\.routineName), ["Main", "Cool-Down"])
    }

    func test_buildExecutionSegments_withBothLinks_returnsWarmUpMainCoolDown() {
        let warmUp = makeRoutine(named: "Warm-Up", exerciseName: "Bike")
        let main = makeRoutine(named: "Main", exerciseName: "Bench Press")
        let coolDown = makeRoutine(named: "Cool-Down", exerciseName: "Walk")
        main.warmUpRoutine = warmUp
        main.coolDownRoutine = coolDown

        let segments = RoutineLinkPlanner.buildExecutionSegments(for: main)

        XCTAssertEqual(segments.map(\.kind), [.warmUp, .main, .coolDown])
        XCTAssertEqual(segments.flatMap(\.exerciseItems).compactMap { $0.exercise?.name }, ["Bike", "Bench Press", "Walk"])
    }

    func test_validate_rejectsSelfLinkedWarmUp() {
        let main = makeRoutine(named: "Main", exerciseName: "Bench Press")
        main.warmUpRoutine = main

        let result = RoutineLinkPlanner.validate(mainRoutine: main)

        XCTAssertEqual(result, .invalid("A routine cannot link itself as its warm-up."))
    }

    func test_validate_rejectsSimpleDirectCycleFromWarmUp() {
        let warmUp = makeRoutine(named: "Warm-Up", exerciseName: "Bike")
        let main = makeRoutine(named: "Main", exerciseName: "Bench Press")
        main.warmUpRoutine = warmUp
        warmUp.coolDownRoutine = main

        let result = RoutineLinkPlanner.validate(mainRoutine: main)

        XCTAssertEqual(result, .invalid("This warm-up routine creates a direct cycle back to the main routine."))
    }

    private func makeRoutine(named routineName: String, exerciseName: String) -> WorkoutRoutine {
        let exercise = Exercise(name: exerciseName)
        let routine = WorkoutRoutine(name: routineName)
        let item = WorkoutRoutineItem(
            order: 0,
            routine: routine,
            exercise: exercise,
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue
        )
        routine.items = [item]
        return routine
    }
}
