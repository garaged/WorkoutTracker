import Foundation
import HealthKit

enum HealthKitWorkoutExportError: LocalizedError, Equatable {
    case healthDataUnavailable
    case permissionDenied
    case sessionMustBeCompleted
    case sessionDatesUnavailable
    case unsupportedActivity

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Apple Health is not available on this device."
        case .permissionDenied:
            return "WorkoutTracker does not have permission to save workouts to Apple Health."
        case .sessionMustBeCompleted:
            return "Only completed tracked activities can be saved to Apple Health."
        case .sessionDatesUnavailable:
            return "This tracked activity is missing the start or end time needed for Apple Health export."
        case .unsupportedActivity:
            return "This tracked activity type cannot be exported to Apple Health yet."
        }
    }
}

struct HealthKitWorkoutExportOutcome: Equatable {
    let routeExportStatus: HealthKitWorkoutRouteExportStatus

    var didSaveRoute: Bool {
        routeExportStatus == .saved
    }
}

struct HealthKitWorkoutExportService {
    private let store: HealthKitStoreProxy
    private let routeExportService: HealthKitWorkoutRouteExportService

    init(
        store: HealthKitStoreProxy = LiveHealthKitStoreProxy(),
        routeExportService: HealthKitWorkoutRouteExportService = HealthKitWorkoutRouteExportService()
    ) {
        self.store = store
        self.routeExportService = routeExportService
    }

    func export(_ payload: TrackedActivityHealthExportPayload) async throws -> HealthKitWorkoutExportOutcome {
        guard store.isHealthDataAvailable() else {
            throw HealthKitWorkoutExportError.healthDataUnavailable
        }

        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            throw HealthKitWorkoutExportError.permissionDenied
        }

        let workout = try await saveWorkout(from: payload)

        let routeExportStatus = try await routeExportService.exportRouteIfAvailable(
            from: payload,
            associatingWith: workout
        )
        return HealthKitWorkoutExportOutcome(routeExportStatus: routeExportStatus)
    }

    func saveWorkout(from payload: TrackedActivityHealthExportPayload) async throws -> HKWorkout {
        guard payload.lifecycleState == .completed else {
            throw HealthKitWorkoutExportError.sessionMustBeCompleted
        }

        guard let startedAt = payload.startedAt, let endedAt = payload.endedAt else {
            throw HealthKitWorkoutExportError.sessionDatesUnavailable
        }

        let activityType = try workoutActivityType(for: payload.activityKind)
        let totalEnergyBurned = payload.activeEnergyKilocalories.map {
            HKQuantity(unit: .kilocalorie(), doubleValue: $0)
        }
        let totalDistance = payload.distanceMeters.map {
            HKQuantity(unit: .meter(), doubleValue: $0)
        }

        let request = HealthKitWorkoutSaveRequest(
            activityType: activityType,
            startDate: startedAt,
            endDate: endedAt,
            totalEnergyBurned: totalEnergyBurned,
            totalDistance: totalDistance,
            metadata: metadata(for: payload)
        )

        return try await store.saveWorkout(request)
    }

    func workoutActivityType(for kind: TrackedActivityKind) throws -> HKWorkoutActivityType {
        switch kind {
        case .walking:
            return .walking
        case .running:
            return .running
        case .hiking:
            return .hiking
        case .yoga:
            return .yoga
        }
    }

    func metadata(for payload: TrackedActivityHealthExportPayload) -> [String: Any]? {
        var values: [String: Any] = [:]

        switch payload.environment {
        case .indoor:
            values[HKMetadataKeyIndoorWorkout] = true
        case .outdoor:
            values[HKMetadataKeyIndoorWorkout] = false
        case .unspecified:
            break
        }

        if payload.hasRecordedRoute {
            values["org.garaged.workouttracker.has_route"] = true
        }

        return values.isEmpty ? nil : values
    }
}
