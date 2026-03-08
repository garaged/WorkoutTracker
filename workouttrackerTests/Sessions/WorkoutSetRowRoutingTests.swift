import XCTest
@testable import workouttracker

final class WorkoutSetRowRoutingTests: XCTestCase {

    func test_shouldUseTimedRow_prefersTrackingStyle_forTimeDistanceExercises() {
        XCTAssertTrue(
            WorkoutSetRowRouting.shouldUseTimedRow(
                trackingStyle: .timeDistance,
                hasTargetDuration: false,
                hasActualDuration: false,
                hasTargetDistance: false,
                hasActualDistance: false
            )
        )
    }

    func test_shouldUseTimedRow_keepsTimedFallback_forLegacyTimedValues() {
        XCTAssertTrue(
            WorkoutSetRowRouting.shouldUseTimedRow(
                trackingStyle: .strength,
                hasTargetDuration: true,
                hasActualDuration: false,
                hasTargetDistance: false,
                hasActualDistance: false
            )
        )
    }

    func test_shouldUseTimedRow_usesStrengthRow_forStrengthExercises_withoutTimedData() {
        XCTAssertFalse(
            WorkoutSetRowRouting.shouldUseTimedRow(
                trackingStyle: .strength,
                hasTargetDuration: false,
                hasActualDuration: false,
                hasTargetDistance: false,
                hasActualDistance: false
            )
        )
    }
}
