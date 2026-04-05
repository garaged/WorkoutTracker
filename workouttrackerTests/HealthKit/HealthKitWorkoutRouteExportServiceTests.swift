import XCTest
import HealthKit
import CoreLocation
@testable import workouttracker

final class HealthKitWorkoutRouteExportServiceTests: XCTestCase {

    func test_exportRouteIfAvailable_returnsSavedWhenLocationsExist() async throws {
        let routeStore = FakeRouteStore(isHealthDataAvailable: true)
        let service = HealthKitWorkoutRouteExportService(store: routeStore)

        let session = makeOutdoorCompletedSession(routePointCount: 2)
        let status = try await service.exportRouteIfAvailable(from: session, associatingWith: makeWorkout())

        XCTAssertEqual(status, .saved)
        XCTAssertEqual(routeStore.saveRouteCallCount, 1)
    }

    func test_exportRouteIfAvailable_returnsNoRouteDataWhenPointsMissing() async throws {
        let routeStore = FakeRouteStore(isHealthDataAvailable: true)
        let service = HealthKitWorkoutRouteExportService(store: routeStore)

        let session = makeOutdoorCompletedSession(routePointCount: 1)
        let status = try await service.exportRouteIfAvailable(from: session, associatingWith: makeWorkout())

        XCTAssertEqual(status, .noRouteData)
        XCTAssertEqual(routeStore.saveRouteCallCount, 0)
    }

    func test_exportRouteIfAvailable_returnsFailedWhenStoreThrows() async throws {
        let routeStore = FakeRouteStore(isHealthDataAvailable: true, saveError: TestError.routeSaveFailed)
        let service = HealthKitWorkoutRouteExportService(store: routeStore)

        let session = makeOutdoorCompletedSession(routePointCount: 2)
        let status = try await service.exportRouteIfAvailable(from: session, associatingWith: makeWorkout())

        guard case .failed(let reason) = status else {
            return XCTFail("Expected route export to fail when the proxy throws.")
        }
        XCTAssertTrue(reason.contains("routeSaveFailed") || !reason.isEmpty)
        XCTAssertEqual(routeStore.saveRouteCallCount, 1)
    }

    private func makeOutdoorCompletedSession(routePointCount: Int) -> TrackedActivitySession {
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        let points = (0..<routePointCount).map { index in
            TrackedActivityRoutePoint(
                location: CLLocation(latitude: 37.0 + (Double(index) * 0.001), longitude: -122.0 + (Double(index) * 0.001))
            )
        }

        return TrackedActivitySession(
            createdAt: start,
            updatedAt: start.addingTimeInterval(600),
            startedAt: start,
            endedAt: start.addingTimeInterval(600),
            activeIntervalStartedAt: nil,
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: 600, distanceMeters: 2_500),
            healthKitExportState: .notRequested,
            routePoints: points
        )
    }

    private func makeWorkout() -> HKWorkout {
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        return HKWorkout(
            activityType: .running,
            start: start,
            end: start.addingTimeInterval(600),
            duration: 600,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: nil
        )
    }
}

private final class FakeRouteStore: HealthKitWorkoutRouteStoreProxy {
    let isHealthDataAvailableValue: Bool
    let saveError: Error?
    private(set) var saveRouteCallCount = 0

    init(isHealthDataAvailable: Bool, saveError: Error? = nil) {
        self.isHealthDataAvailableValue = isHealthDataAvailable
        self.saveError = saveError
    }

    func isHealthDataAvailable() -> Bool { isHealthDataAvailableValue }

    func saveRoute(for workout: HKWorkout, locations: [CLLocation], metadata: [String : Any]?) async throws {
        saveRouteCallCount += 1
        if let saveError { throw saveError }
    }
}

private enum TestError: Error {
    case routeSaveFailed
}
