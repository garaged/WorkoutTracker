import XCTest
@testable import workouttracker

@MainActor
final class ExerciseRoutineRoleMetadataTests: XCTestCase {

    func test_setRoutineRoles_roundTripsSortedUniqueRoles() {
        let exercise = Exercise(name: "Walking")

        exercise.setRoutineRoles([.coolDown, .warmUp, .coolDown])

        XCTAssertEqual(exercise.routineRolesRaw, "coolDown,warmUp")
        XCTAssertEqual(exercise.routineRoles, [.warmUp, .coolDown])
        XCTAssertTrue(exercise.supportsRoutineRole(.warmUp))
        XCTAssertTrue(exercise.supportsRoutineRole(.coolDown))
    }

    func test_supportsRoutineRole_returnsFalseWhenNoRolesAreStored() {
        let exercise = Exercise(name: "Bench Press")

        XCTAssertNil(exercise.routineRolesRaw)
        XCTAssertTrue(exercise.routineRoles.isEmpty)
        XCTAssertFalse(exercise.supportsRoutineRole(.warmUp))
        XCTAssertFalse(exercise.supportsRoutineRole(.coolDown))
    }

    func test_routineRoles_ignoresUnknownStoredValues() {
        let exercise = Exercise(name: "Mobility Flow")
        exercise.routineRolesRaw = "warmUp,unknown,coolDown"

        XCTAssertEqual(exercise.routineRoles, [.warmUp, .coolDown])
    }
}
