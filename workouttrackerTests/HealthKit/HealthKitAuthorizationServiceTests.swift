import XCTest
import HealthKit
@testable import workouttracker

@MainActor
final class HealthKitAuthorizationServiceTests: XCTestCase {
    func testAuthorizationState_unavailableWhenHealthDataIsUnavailable() {
        let store = MockHealthKitStoreProxy(
            isHealthDataAvailable: false,
            authorizationStatus: .notDetermined
        )

        let service = HealthKitAuthorizationService(store: store)

        XCTAssertEqual(service.state, .unavailable)
    }

    func testAuthorizationState_deniedWhenWorkoutWritePermissionIsDenied() {
        let store = MockHealthKitStoreProxy(
            isHealthDataAvailable: true,
            authorizationStatus: .sharingDenied
        )

        let service = HealthKitAuthorizationService(store: store)

        XCTAssertEqual(service.state, .denied)
    }

    func testRequestAuthorization_refreshesAuthorizedState() async throws {
        let store = MockHealthKitStoreProxy(
            isHealthDataAvailable: true,
            authorizationStatus: .notDetermined,
            requestAuthorizationResult: true,
            authorizationStatusAfterRequest: .sharingAuthorized
        )

        let service = HealthKitAuthorizationService(store: store)
        let state = try await service.requestAuthorization()

        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(service.state, .authorized)
        XCTAssertEqual(store.requestAuthorizationCallCount, 1)
    }
}

private final class MockHealthKitStoreProxy: HealthKitStoreProxy {
    var isHealthDataAvailableValue: Bool
    var authorizationStatusValue: HKAuthorizationStatus
    var requestAuthorizationResult: Bool
    var authorizationStatusAfterRequest: HKAuthorizationStatus?
    var requestAuthorizationCallCount = 0

    init(
        isHealthDataAvailable: Bool,
        authorizationStatus: HKAuthorizationStatus,
        requestAuthorizationResult: Bool = true,
        authorizationStatusAfterRequest: HKAuthorizationStatus? = nil
    ) {
        self.isHealthDataAvailableValue = isHealthDataAvailable
        self.authorizationStatusValue = authorizationStatus
        self.requestAuthorizationResult = requestAuthorizationResult
        self.authorizationStatusAfterRequest = authorizationStatusAfterRequest
    }

    func isHealthDataAvailable() -> Bool {
        isHealthDataAvailableValue
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws -> Bool {
        requestAuthorizationCallCount += 1
        if let authorizationStatusAfterRequest {
            authorizationStatusValue = authorizationStatusAfterRequest
        }
        return requestAuthorizationResult
    }

    func save(_ workout: HKWorkout) async throws {
        XCTFail("save(_:) should not be called in authorization tests")
    }
}
