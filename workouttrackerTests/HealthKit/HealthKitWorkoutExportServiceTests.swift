import XCTest
import HealthKit
import CoreLocation
@testable import workouttracker

final class HealthKitWorkoutExportServiceTests: XCTestCase {
    func testSaveWorkout_runningMapsDistanceEnergyAndIndoorMetadata() async throws {
        let session = TrackedActivitySession(
            createdAt: referenceDate,
            updatedAt: referenceDate,
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(1_800),
            activityKind: .running,
            environment: .indoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(
                elapsedDuration: 1_800,
                distanceMeters: 5_000,
                activeEnergyKilocalories: 420,
                stepCount: 6_000
            ),
            notes: "Tempo"
        )

        let store = MockExportHealthKitStoreProxy()
        let service = HealthKitWorkoutExportService(store: store)
        _ = try await service.saveWorkout(from: session)

        let request = try XCTUnwrap(store.savedRequests.first)
        XCTAssertEqual(request.activityType, .running)
        XCTAssertEqual(request.startDate, referenceDate)
        XCTAssertEqual(request.endDate, referenceDate.addingTimeInterval(1_800))
        let totalDistance = try XCTUnwrap(request.totalDistance)
        XCTAssertEqual(totalDistance.doubleValue(for: .meter()), 5_000, accuracy: 0.001)
        let totalEnergyBurned = try XCTUnwrap(request.totalEnergyBurned)
        XCTAssertEqual(totalEnergyBurned.doubleValue(for: .kilocalorie()), 420, accuracy: 0.001)
        XCTAssertEqual(request.metadata?[HKMetadataKeyIndoorWorkout] as? Bool, true)
    }

    func testExport_callsSaveWhenAuthorized() async throws {
        let store = MockExportHealthKitStoreProxy()
        let service = HealthKitWorkoutExportService(
            store: store,
            routeExportService: HealthKitWorkoutRouteExportService(store: MockWorkoutRouteStoreProxy())
        )
        let session = completedYogaSession()

        let outcome = try await service.export(session)

        XCTAssertEqual(store.savedRequests.count, 1)
        XCTAssertEqual(store.savedRequests.first?.activityType, .yoga)
        XCTAssertFalse(outcome.didSaveRoute)
    }

    func testExport_outdoorRouteReturnsRouteOutcomeWhenAvailable() async throws {
        let store = MockExportHealthKitStoreProxy()
        let routeStore = MockWorkoutRouteStoreProxy()
        let service = HealthKitWorkoutExportService(
            store: store,
            routeExportService: HealthKitWorkoutRouteExportService(store: routeStore)
        )

        let session = TrackedActivitySession(
            createdAt: referenceDate,
            updatedAt: referenceDate,
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(2_400),
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: 2_400, distanceMeters: 6_500),
            routePoints: [
                TrackedActivityRoutePoint(location: CLLocation(latitude: 37.3317, longitude: -122.0301)),
                TrackedActivityRoutePoint(location: CLLocation(latitude: 37.3322, longitude: -122.0296))
            ]
        )

        let outcome = try await service.export(session)

        XCTAssertTrue(outcome.didSaveRoute)
        XCTAssertEqual(routeStore.savedLocations.count, 2)
    }

    func testExport_throwsWhenNotAuthorized() async {
        let store = MockExportHealthKitStoreProxy(authorizationStatus: .sharingDenied)
        let service = HealthKitWorkoutExportService(store: store)
        let session = completedYogaSession()

        await XCTAssertThrowsErrorAsync(try await service.export(session)) { error in
            XCTAssertEqual(error as? HealthKitWorkoutExportError, .permissionDenied)
        }
    }

    private func completedYogaSession() -> TrackedActivitySession {
        TrackedActivitySession(
            createdAt: referenceDate,
            updatedAt: referenceDate,
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(900),
            activityKind: .yoga,
            environment: .indoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: 900, activeEnergyKilocalories: 120)
        )
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 1_721_234_567)
    }
}

private final class MockExportHealthKitStoreProxy: HealthKitStoreProxy {
    var isHealthDataAvailableValue: Bool
    var authorizationStatusValue: HKAuthorizationStatus
    var savedRequests: [HealthKitWorkoutSaveRequest] = []

    init(
        isHealthDataAvailable: Bool = true,
        authorizationStatus: HKAuthorizationStatus = .sharingAuthorized
    ) {
        self.isHealthDataAvailableValue = isHealthDataAvailable
        self.authorizationStatusValue = authorizationStatus
    }

    func isHealthDataAvailable() -> Bool {
        isHealthDataAvailableValue
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws -> Bool {
        true
    }

    func saveWorkout(_ request: HealthKitWorkoutSaveRequest) async throws -> HKWorkout {
        savedRequests.append(request)
        return makeStubWorkout()
    }
}

private final class MockWorkoutRouteStoreProxy: HealthKitWorkoutRouteStoreProxy {
    var isHealthDataAvailableValue: Bool = true
    var savedLocations: [CLLocation] = []

    func isHealthDataAvailable() -> Bool {
        isHealthDataAvailableValue
    }

    func saveRoute(for workout: HKWorkout, locations: [CLLocation], metadata: [String : Any]?) async throws {
        savedLocations = locations
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

private func makeStubWorkout() -> HKWorkout {
    // Tests only pass this through to collaborators that never read workout fields.
    unsafeBitCast(NSObject(), to: HKWorkout.self)
}
