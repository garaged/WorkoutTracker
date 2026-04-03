import XCTest
import HealthKit
@testable import workouttracker

final class HealthKitWorkoutExportServiceTests: XCTestCase {
    func testMakeWorkout_runningMapsDistanceEnergyAndIndoorMetadata() throws {
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

        let service = HealthKitWorkoutExportService(store: MockExportHealthKitStoreProxy())
        let workout = try service.makeWorkout(from: session)

        XCTAssertEqual(workout.workoutActivityType, .running)
        XCTAssertEqual(workout.duration, 1_800, accuracy: 0.001)
        
        let totalDistance = try XCTUnwrap(workout.totalDistance)
        XCTAssertEqual(totalDistance.doubleValue(for: .meter()), 5_000, accuracy: 0.001)

        let totalEnergyBurned = try XCTUnwrap(workout.totalEnergyBurned)
        XCTAssertEqual(totalEnergyBurned.doubleValue(for: .kilocalorie()), 420, accuracy: 0.001)
        
        XCTAssertEqual(workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool, true)
    }

    func testExport_callsSaveWhenAuthorized() async throws {
        let store = MockExportHealthKitStoreProxy()
        let service = HealthKitWorkoutExportService(store: store)
        let session = completedYogaSession()

        try await service.export(session)

        XCTAssertEqual(store.savedWorkouts.count, 1)
        XCTAssertEqual(store.savedWorkouts.first?.workoutActivityType, .yoga)
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
    var savedWorkouts: [HKWorkout] = []

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

    func save(_ workout: HKWorkout) async throws {
        savedWorkouts.append(workout)
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
