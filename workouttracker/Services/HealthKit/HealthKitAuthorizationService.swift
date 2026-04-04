import Foundation
import HealthKit
import Combine

protocol HealthKitStoreProxy {
    func isHealthDataAvailable() -> Bool
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws -> Bool
    func save(_ workout: HKWorkout) async throws
}

struct LiveHealthKitStoreProxy: HealthKitStoreProxy {
    private let healthStore = HKHealthStore()

    func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }

    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func save(_ workout: HKWorkout) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(workout) { success, error in
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
}

enum HealthKitAuthorizationError: LocalizedError {
    case requestDidNotComplete
    case unknownSaveFailure

    var errorDescription: String? {
        switch self {
        case .requestDidNotComplete:
            return String(
                localized: "health.error.permission_request_incomplete",
                defaultValue: "Apple Health permission could not be granted."
            )
        case .unknownSaveFailure:
            return String(
                localized: "health.error.unknown_save_failure",
                defaultValue: "The workout could not be saved to Apple Health."
            )
        }
    }
}

@MainActor
final class HealthKitAuthorizationService: ObservableObject {
    enum AuthorizationState: Equatable {
        case unavailable
        case notRequested
        case denied
        case authorized

        var title: String {
            switch self {
            case .unavailable:
                return String(localized: "health.authorization.title.unavailable", defaultValue: "Apple Health unavailable")
            case .notRequested:
                return String(localized: "health.authorization.title.not_connected", defaultValue: "Not connected")
            case .denied:
                return String(localized: "health.authorization.title.permission_needed", defaultValue: "Permission needed")
            case .authorized:
                return String(localized: "health.authorization.title.connected", defaultValue: "Connected")
            }
        }

        var message: String {
            switch self {
            case .unavailable:
                return String(
                    localized: "health.authorization.message.unavailable",
                    defaultValue: "Apple Health is not available on this device. Tracked activities still stay in WorkoutTracker locally."
                )
            case .notRequested:
                return String(
                    localized: "health.authorization.message.not_requested",
                    defaultValue: "WorkoutTracker can save completed tracked activities to Apple Health. Outdoor walks, runs, and hikes can also include route data when Apple Health and Location access are available."
                )
            case .denied:
                return String(
                    localized: "health.authorization.message.denied",
                    defaultValue: "WorkoutTracker does not currently have permission to save tracked activities to Apple Health. You can still track locally and enable Apple Health later."
                )
            case .authorized:
                return String(
                    localized: "health.authorization.message.authorized",
                    defaultValue: "Completed tracked activities can be saved to Apple Health. Eligible outdoor routes can be attached when location access is also available."
                )
            }
        }

        var ctaTitle: String? {
            switch self {
            case .notRequested:
                return String(localized: "health.authorization.cta.enable", defaultValue: "Enable Apple Health")
            case .denied:
                return String(localized: "health.authorization.cta.open_settings", defaultValue: "Open Settings")
            case .unavailable, .authorized:
                return nil
            }
        }
    }

    @Published private(set) var state: AuthorizationState

    private let store: HealthKitStoreProxy

    init(store: HealthKitStoreProxy = LiveHealthKitStoreProxy()) {
        self.store = store
        self.state = Self.authorizationState(using: store)
    }

    var isAvailable: Bool {
        state != .unavailable
    }

    var canExportWorkouts: Bool {
        state == .authorized
    }

    func refresh() {
        state = Self.authorizationState(using: store)
    }

    @discardableResult
    func requestAuthorization() async throws -> AuthorizationState {
        guard store.isHealthDataAvailable() else {
            state = .unavailable
            return state
        }

        let didRequest = try await store.requestAuthorization(
            toShare: Self.workoutShareTypes,
            read: []
        )

        if !didRequest {
            throw HealthKitAuthorizationError.requestDidNotComplete
        }

        state = Self.authorizationState(using: store)
        return state
    }

    static var workoutShareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
    }

    static func authorizationState(using store: HealthKitStoreProxy) -> AuthorizationState {
        guard store.isHealthDataAvailable() else {
            return .unavailable
        }

        switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .notDetermined:
            return .notRequested
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .notRequested
        }
    }
}
