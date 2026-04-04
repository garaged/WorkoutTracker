import Foundation
import HealthKit
import CoreLocation

protocol HealthKitWorkoutRouteStoreProxy {
    func isHealthDataAvailable() -> Bool
    func saveRoute(for workout: HKWorkout, locations: [CLLocation], metadata: [String: Any]?) async throws
}

struct LiveHealthKitWorkoutRouteStoreProxy: HealthKitWorkoutRouteStoreProxy {
    private let healthStore = HKHealthStore()

    func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func saveRoute(for workout: HKWorkout, locations: [CLLocation], metadata: [String: Any]?) async throws {
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
        try await insert(locations, into: routeBuilder)
        _ = try await finish(routeBuilder, workout: workout, metadata: metadata)
    }

    private func insert(_ locations: [CLLocation], into builder: HKWorkoutRouteBuilder) async throws {
        guard !locations.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.insertRouteData(locations) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitAuthorizationError.unknownSaveFailure)
                }
            }
        }
    }

    private func finish(_ builder: HKWorkoutRouteBuilder, workout: HKWorkout, metadata: [String: Any]?) async throws -> HKWorkoutRoute {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkoutRoute, Error>) in
            builder.finishRoute(with: workout, metadata: metadata) { route, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let route {
                    continuation.resume(returning: route)
                } else {
                    continuation.resume(throwing: HealthKitAuthorizationError.unknownSaveFailure)
                }
            }
        }
    }
}

enum HealthKitWorkoutRouteExportStatus: Equatable {
    case notApplicable
    case noRouteData
    case saved
    case failed(String)
}

struct HealthKitWorkoutRouteExportService {
    private let store: HealthKitWorkoutRouteStoreProxy

    init(store: HealthKitWorkoutRouteStoreProxy = LiveHealthKitWorkoutRouteStoreProxy()) {
        self.store = store
    }

    func exportRouteIfAvailable(from session: TrackedActivitySession, associatingWith workout: HKWorkout) async throws -> HealthKitWorkoutRouteExportStatus {
        guard store.isHealthDataAvailable() else {
            return .failed("Apple Health route data is not available on this device.")
        }

        guard session.environment == .outdoor, session.activityKind.supportsDistance else {
            return .notApplicable
        }

        let locations = session.routePoints.map(\.location)
        guard locations.count > 1 else {
            return .noRouteData
        }

        do {
            try await store.saveRoute(for: workout, locations: locations, metadata: metadata(for: session))
            return .saved
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func metadata(for session: TrackedActivitySession) -> [String: Any]? {
        guard session.routePointCount > 0 else { return nil }
        return [
            "org.garaged.workouttracker.route_point_count": session.routePointCount
        ]
    }
}
