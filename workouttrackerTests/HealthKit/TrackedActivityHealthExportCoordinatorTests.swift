import XCTest
import SwiftData
import HealthKit
import CoreLocation
@testable import workouttracker

@MainActor
final class TrackedActivityHealthExportCoordinatorTests: XCTestCase {

    func test_autoExportIfEnabled_completedSession_marksExportedAndReturnsAutomaticRouteMessage() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = makeCompletedOutdoorSession()
        context.insert(session)
        try context.save()

        let healthStore = FakeHealthStore(authorizationStatus: .sharingAuthorized)
        let routeStore = FakeRouteStore(isHealthDataAvailable: true)
        let exportService = HealthKitWorkoutExportService(
            store: healthStore,
            routeExportService: HealthKitWorkoutRouteExportService(store: routeStore)
        )
        let coordinator = TrackedActivityHealthExportCoordinator(
            recorder: TrackedActivityRecorder(),
            exportService: exportService
        )

        let message = try await coordinator.autoExportIfEnabled(for: session, isEnabled: true, context: context)

        XCTAssertEqual(healthStore.saveCallCount, 1)
        XCTAssertEqual(routeStore.saveRouteCallCount, 1)
        XCTAssertEqual(session.healthKitExportState, .exported)
        XCTAssertNotNil(session.healthKitExportSucceededAt)
        XCTAssertEqual(session.hasLocalChangesSinceHealthKitExport, false)
        XCTAssertEqual(message, "Saved automatically to Apple Health with your outdoor route.")
    }

    func test_autoExportIfEnabled_disabled_doesNothing() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = makeCompletedOutdoorSession()
        context.insert(session)
        try context.save()

        let healthStore = FakeHealthStore(authorizationStatus: .sharingAuthorized)
        let exportService = HealthKitWorkoutExportService(
            store: healthStore,
            routeExportService: HealthKitWorkoutRouteExportService(store: FakeRouteStore(isHealthDataAvailable: true))
        )
        let coordinator = TrackedActivityHealthExportCoordinator(
            recorder: TrackedActivityRecorder(),
            exportService: exportService
        )

        let message = try await coordinator.autoExportIfEnabled(for: session, isEnabled: false, context: context)

        XCTAssertNil(message)
        XCTAssertEqual(healthStore.saveCallCount, 0)
        XCTAssertEqual(session.healthKitExportState, .notRequested)
    }

    func test_export_permissionDenied_marksFailureStateAndMessage() async {
        do {
            let container = try makeContainer()
            let context = ModelContext(container)
            let session = makeCompletedOutdoorSession()
            context.insert(session)
            try context.save()

            let healthStore = FakeHealthStore(authorizationStatus: .sharingDenied)
            let exportService = HealthKitWorkoutExportService(
                store: healthStore,
                routeExportService: HealthKitWorkoutRouteExportService(store: FakeRouteStore(isHealthDataAvailable: true))
            )
            let coordinator = TrackedActivityHealthExportCoordinator(
                recorder: TrackedActivityRecorder(),
                exportService: exportService
            )

            do {
                _ = try await coordinator.export(session, trigger: .manual, context: context)
                XCTFail("Expected export to throw when Health authorization is denied.")
            } catch let error as HealthKitWorkoutExportError {
                XCTAssertEqual(error, .permissionDenied)
            } catch {
                XCTFail("Expected HealthKitWorkoutExportError.permissionDenied, got \(error)")
            }

            XCTAssertEqual(session.healthKitExportState, .failed)
            XCTAssertNotNil(session.healthKitExportFailureMessage)
            XCTAssertTrue(session.healthKitExportFailureMessage?.contains("permission") == true || session.healthKitExportFailureMessage?.contains("Apple Health") == true)
        } catch {
            XCTFail("Unexpected test setup failure: \(error)")
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([TrackedActivitySession.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeCompletedOutdoorSession() -> TrackedActivitySession {
        let start = Date(timeIntervalSinceReferenceDate: 20_000)
        let end = start.addingTimeInterval(900)
        let points = [
            TrackedActivityRoutePoint(location: CLLocation(latitude: 37.3317, longitude: -122.0301)),
            TrackedActivityRoutePoint(location: CLLocation(latitude: 37.3327, longitude: -122.0291))
        ]

        return TrackedActivitySession(
            createdAt: start,
            updatedAt: end,
            startedAt: start,
            endedAt: end,
            activeIntervalStartedAt: nil,
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: 900, distanceMeters: 3_100, activeEnergyKilocalories: 220, stepCount: 4_200),
            healthKitExportState: .notRequested,
            routePoints: points
        )
    }
}

private final class FakeHealthStore: HealthKitStoreProxy {
    let authorizationStatusValue: HKAuthorizationStatus
    private(set) var saveCallCount = 0

    init(authorizationStatus: HKAuthorizationStatus) {
        self.authorizationStatusValue = authorizationStatus
    }

    func isHealthDataAvailable() -> Bool { true }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws -> Bool {
        true
    }

    func save(_ workout: HKWorkout) async throws {
        saveCallCount += 1
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
