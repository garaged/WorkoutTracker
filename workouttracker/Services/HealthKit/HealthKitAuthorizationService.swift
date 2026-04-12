import Foundation
import HealthKit
import Combine

struct HealthKitWorkoutSaveRequest {
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let totalEnergyBurned: HKQuantity?
    let totalDistance: HKQuantity?
    let metadata: [String: Any]?
}

protocol HealthKitStoreProxy {
    func isHealthDataAvailable() -> Bool
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws -> Bool
    func saveWorkout(_ request: HealthKitWorkoutSaveRequest) async throws -> HKWorkout
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

    func saveWorkout(_ request: HealthKitWorkoutSaveRequest) async throws -> HKWorkout {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = request.activityType

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: nil
        )

        try await builder.beginCollection(at: request.startDate)

        if let metadata = request.metadata, metadata.isEmpty == false {
            try await builder.addMetadata(metadata)
        }

        var samples: [HKSample] = []

        if let totalEnergyBurned = request.totalEnergyBurned,
           let quantityType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
           authorizationStatus(for: quantityType) == .sharingAuthorized {
            samples.append(
                HKQuantitySample(
                    type: quantityType,
                    quantity: totalEnergyBurned,
                    start: request.startDate,
                    end: request.endDate
                )
            )
        }

        if let totalDistance = request.totalDistance,
           let quantityType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
           authorizationStatus(for: quantityType) == .sharingAuthorized {
            samples.append(
                HKQuantitySample(
                    type: quantityType,
                    quantity: totalDistance,
                    start: request.startDate,
                    end: request.endDate
                )
            )
        }

        if samples.isEmpty == false {
            try await builder.addSamples(samples)
        }

        try await builder.endCollection(at: request.endDate)

        guard let workout = try await builder.finishWorkout() else {
            throw HealthKitAuthorizationError.unknownSaveFailure
        }

        return workout
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

    enum RouteAuthorizationState: Equatable {
        case unavailable
        case notRequested
        case denied
        case authorized

        var title: String {
            switch self {
            case .unavailable:
                return String(localized: "health.route_authorization.title.unavailable", defaultValue: "Unavailable")
            case .notRequested:
                return String(localized: "health.route_authorization.title.permission_needed", defaultValue: "Permission needed")
            case .denied:
                return String(localized: "health.route_authorization.title.permission_needed", defaultValue: "Permission needed")
            case .authorized:
                return String(localized: "health.route_authorization.title.ready", defaultValue: "Ready")
            }
        }

        var message: String {
            switch self {
            case .unavailable:
                return String(
                    localized: "health.route_authorization.message.unavailable",
                    defaultValue: "Apple Health route export is not available on this device. Outdoor route points can still stay local in WorkoutTracker."
                )
            case .notRequested:
                return String(
                    localized: "health.route_authorization.message.not_requested",
                    defaultValue: "WorkoutTracker can save workouts to Apple Health, but outdoor route attachment still needs Apple Health route access."
                )
            case .denied:
                return String(
                    localized: "health.route_authorization.message.denied",
                    defaultValue: "WorkoutTracker can save workouts to Apple Health, but outdoor route attachment is currently blocked until route access is re-enabled in Settings."
                )
            case .authorized:
                return String(
                    localized: "health.route_authorization.message.authorized",
                    defaultValue: "Outdoor route attachment is ready when route points are captured and the workout is saved."
                )
            }
        }
    }

    enum RoutePermissionAction: Equatable {
        case requestAuthorization
        case openSettings
    }

    @Published private(set) var state: AuthorizationState
    @Published private(set) var routeState: RouteAuthorizationState

    private let store: HealthKitStoreProxy

    init(store: HealthKitStoreProxy = LiveHealthKitStoreProxy()) {
        self.store = store
        self.state = Self.authorizationState(using: store)
        self.routeState = Self.routeAuthorizationState(using: store)
    }

    var isAvailable: Bool {
        state != .unavailable
    }

    var canExportWorkouts: Bool {
        state == .authorized
    }

    var canExportRoutes: Bool {
        canExportWorkouts && routeState == .authorized
    }

    var routePermissionAction: RoutePermissionAction? {
        guard canExportWorkouts else { return nil }
        switch routeState {
        case .notRequested:
            return .requestAuthorization
        case .denied:
            return .openSettings
        case .authorized, .unavailable:
            return nil
        }
    }

    var routePermissionActionTitle: String? {
        switch routePermissionAction {
        case .requestAuthorization:
            return String(localized: "health.route_authorization.cta.enable", defaultValue: "Enable route access")
        case .openSettings:
            return String(localized: "health.route_authorization.cta.open_settings", defaultValue: "Open Settings")
        case nil:
            return nil
        }
    }

    var statusSummaryMessage: String {
        guard state == .authorized else {
            return state.message
        }

        switch routeState {
        case .authorized:
            return state.message
        case .notRequested:
            return String(
                localized: "health.authorization.summary.workout_only_not_requested",
                defaultValue: "WorkoutTracker can save completed tracked activities to Apple Health. Outdoor route attachment still needs Apple Health route access."
            )
        case .denied:
            return String(
                localized: "health.authorization.summary.workout_only_denied",
                defaultValue: "WorkoutTracker can save completed tracked activities to Apple Health, but outdoor route attachment is currently blocked until route access is re-enabled in Settings."
            )
        case .unavailable:
            return String(
                localized: "health.authorization.summary.route_unavailable",
                defaultValue: "WorkoutTracker can save completed tracked activities to Apple Health, but outdoor route attachment is unavailable on this device."
            )
        }
    }

    func refresh() {
        state = Self.authorizationState(using: store)
        routeState = Self.routeAuthorizationState(using: store)
    }

    @discardableResult
    func requestAuthorization() async throws -> AuthorizationState {
        guard store.isHealthDataAvailable() else {
            state = .unavailable
            routeState = .unavailable
            return state
        }

        let didRequest = try await store.requestAuthorization(
            toShare: Self.workoutShareTypes,
            read: []
        )

        if !didRequest {
            throw HealthKitAuthorizationError.requestDidNotComplete
        }

        refresh()
        return state
    }

    static var workoutShareTypes: Set<HKSampleType> {
        var shareTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            shareTypes.insert(activeEnergy)
        }

        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            shareTypes.insert(distance)
        }

        return shareTypes
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

    static func routeAuthorizationState(using store: HealthKitStoreProxy) -> RouteAuthorizationState {
        guard store.isHealthDataAvailable() else {
            return .unavailable
        }

        switch authorizationState(using: store) {
        case .unavailable:
            return .unavailable
        case .notRequested:
            return .notRequested
        case .denied:
            return .denied
        case .authorized:
            break
        }

        switch store.authorizationStatus(for: HKSeriesType.workoutRoute()) {
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
