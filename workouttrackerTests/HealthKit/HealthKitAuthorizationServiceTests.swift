import XCTest
import HealthKit
@testable import workouttracker

@MainActor
final class HealthKitAuthorizationServiceTests: XCTestCase {
    func testAuthorizationState_unavailableWhenHealthDataIsUnavailable() {
        let store = MockHealthKitStoreProxy(
            isHealthDataAvailable: false,
            workoutAuthorizationStatus: .notDetermined,
            routeAuthorizationStatus: .notDetermined
        )

        let service = HealthKitAuthorizationService(store: store)

        XCTAssertEqual(service.state, .unavailable)
        XCTAssertEqual(service.routeState, .unavailable)
    }

    func testAuthorizationState_deniedWhenWorkoutWritePermissionIsDenied() {
        let store = MockHealthKitStoreProxy(
            isHealthDataAvailable: true,
            workoutAuthorizationStatus: .sharingDenied,
            routeAuthorizationStatus: .sharingAuthorized
        )

        let service = HealthKitAuthorizationService(store: store)

        XCTAssertEqual(service.state, .denied)
        XCTAssertEqual(service.routeState, .denied)
    }

    func testRouteAuthorizationState_notRequestedWhenWorkoutAuthorizedButRouteStillNeedsAccess() {
        let store = MockHealthKitStoreProxy(
            isHealthDataAvailable: true,
            workoutAuthorizationStatus: .sharingAuthorized,
            routeAuthorizationStatus: .notDetermined
        )

        let service = HealthKitAuthorizationService(store: store)

        XCTAssertEqual(service.state, .authorized)
        XCTAssertEqual(service.routeState, .notRequested)
        XCTAssertTrue(service.canExportWorkouts)
        XCTAssertFalse(service.canExportRoutes)
        XCTAssertEqual(service.routePermissionAction, .requestAuthorization)
    }

    func testRouteAuthorizationState_deniedWhenWorkoutAuthorizedButRouteWasRevoked() {
        let store = MockHealthKitStoreProxy(
            isHealthDataAvailable: true,
            workoutAuthorizationStatus: .sharingAuthorized,
            routeAuthorizationStatus: .sharingDenied
        )

        let service = HealthKitAuthorizationService(store: store)

        XCTAssertEqual(service.state, .authorized)
        XCTAssertEqual(service.routeState, .denied)
        XCTAssertTrue(service.canExportWorkouts)
        XCTAssertFalse(service.canExportRoutes)
        XCTAssertEqual(service.routePermissionAction, .openSettings)
    }

    func testRequestAuthorization_refreshesAuthorizedWorkoutAndRouteState() async throws {
        let store = MockHealthKitStoreProxy(
            isHealthDataAvailable: true,
            workoutAuthorizationStatus: .notDetermined,
            routeAuthorizationStatus: .notDetermined,
            requestAuthorizationResult: true,
            workoutAuthorizationStatusAfterRequest: .sharingAuthorized,
            routeAuthorizationStatusAfterRequest: .sharingAuthorized
        )

        let service = HealthKitAuthorizationService(store: store)
        let state = try await service.requestAuthorization()

        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(service.state, .authorized)
        XCTAssertEqual(service.routeState, .authorized)
        XCTAssertEqual(store.requestAuthorizationCallCount, 1)
    }
}

private final class MockHealthKitStoreProxy: HealthKitStoreProxy {
    var isHealthDataAvailableValue: Bool
    var workoutAuthorizationStatusValue: HKAuthorizationStatus
    var routeAuthorizationStatusValue: HKAuthorizationStatus
    var requestAuthorizationResult: Bool
    var workoutAuthorizationStatusAfterRequest: HKAuthorizationStatus?
    var routeAuthorizationStatusAfterRequest: HKAuthorizationStatus?
    var requestAuthorizationCallCount = 0

    init(
        isHealthDataAvailable: Bool,
        workoutAuthorizationStatus: HKAuthorizationStatus,
        routeAuthorizationStatus: HKAuthorizationStatus,
        requestAuthorizationResult: Bool = true,
        workoutAuthorizationStatusAfterRequest: HKAuthorizationStatus? = nil,
        routeAuthorizationStatusAfterRequest: HKAuthorizationStatus? = nil
    ) {
        self.isHealthDataAvailableValue = isHealthDataAvailable
        self.workoutAuthorizationStatusValue = workoutAuthorizationStatus
        self.routeAuthorizationStatusValue = routeAuthorizationStatus
        self.requestAuthorizationResult = requestAuthorizationResult
        self.workoutAuthorizationStatusAfterRequest = workoutAuthorizationStatusAfterRequest
        self.routeAuthorizationStatusAfterRequest = routeAuthorizationStatusAfterRequest
    }

    func isHealthDataAvailable() -> Bool {
        isHealthDataAvailableValue
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        if type.identifier == HKObjectType.workoutType().identifier {
            return workoutAuthorizationStatusValue
        }
        if type.identifier == HKSeriesType.workoutRoute().identifier {
            return routeAuthorizationStatusValue
        }
        return .notDetermined
    }

    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws -> Bool {
        requestAuthorizationCallCount += 1
        if let workoutAuthorizationStatusAfterRequest {
            workoutAuthorizationStatusValue = workoutAuthorizationStatusAfterRequest
        }
        if let routeAuthorizationStatusAfterRequest {
            routeAuthorizationStatusValue = routeAuthorizationStatusAfterRequest
        }
        return requestAuthorizationResult
    }

    func save(_ workout: HKWorkout) async throws {
        XCTFail("save(_:) should not be called in authorization tests")
    }
}
