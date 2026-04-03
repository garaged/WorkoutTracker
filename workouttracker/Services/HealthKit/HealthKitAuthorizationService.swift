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
}

enum HealthKitAuthorizationError: LocalizedError {
    case requestDidNotComplete
    case unknownSaveFailure

    var errorDescription: String? {
        switch self {
        case .requestDidNotComplete:
            return "Apple Health permission could not be granted."
        case .unknownSaveFailure:
            return "The workout could not be saved to Apple Health."
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
                return "Apple Health unavailable"
            case .notRequested:
                return "Not connected"
            case .denied:
                return "Permission needed"
            case .authorized:
                return "Connected"
            }
        }

        var message: String {
            switch self {
            case .unavailable:
                return "Apple Health is not available on this device. Tracked activities still stay in WorkoutTracker locally."
            case .notRequested:
                return "WorkoutTracker can save completed tracked activities to Apple Health. This release only writes your finished tracked activities; it does not import external Health workouts yet."
            case .denied:
                return "WorkoutTracker does not currently have permission to save tracked activities to Apple Health. You can still track locally and enable Apple Health later."
            case .authorized:
                return "Completed tracked activities can be saved to Apple Health."
            }
        }

        var ctaTitle: String? {
            switch self {
            case .notRequested:
                return "Enable Apple Health"
            case .denied:
                return "Open Settings"
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
        [HKObjectType.workoutType()]
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
