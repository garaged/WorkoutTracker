import Foundation
import Combine
import CoreLocation

@MainActor
final class OutdoorRouteRecorder: NSObject, ObservableObject {

    enum CaptureState: Equatable {
        case notEligible
        case idle
        case requestingPermission
        case permissionDenied
        case paused
        case searchingForLocation
        case recording
        case unavailable
        case failed(String)

        var title: String {
            switch self {
            case .notEligible:
                return "Not applicable"
            case .idle:
                return "Ready"
            case .requestingPermission:
                return "Permission needed"
            case .permissionDenied:
                return "Location denied"
            case .paused:
                return "Paused"
            case .searchingForLocation:
                return "Acquiring location"
            case .recording:
                return "Recording route"
            case .unavailable:
                return "Location unavailable"
            case .failed:
                return "Route capture issue"
            }
        }

        var message: String {
            switch self {
            case .notEligible:
                return "Only outdoor walks, runs, and hikes record route data."
            case .idle:
                return "Route capture is ready when this outdoor activity is active."
            case .requestingPermission:
                return "Allow location while using the app to capture an outdoor route."
            case .permissionDenied:
                return "WorkoutTracker does not currently have permission to capture your route. Any points already captured stay local, but new route points cannot be recorded until location access is restored."
            case .paused:
                return "Route capture is paused while this activity is paused."
            case .searchingForLocation:
                return "WorkoutTracker is waiting for the first reliable location fix. This can take a moment outdoors, and iPhone Simulator also needs an active simulated location or GPX route."
            case .recording:
                return "Location updates are being collected for this route while the live activity stays open on iPhone."
            case .unavailable:
                return "Location services are not available on this device."
            case .failed(let message):
                return message
            }
        }
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var captureState: CaptureState = .idle
    @Published private(set) var capturedPoints: [TrackedActivityRoutePoint] = []
    @Published private(set) var derivedDistanceMeters: Double?

    private let locationManager: CLLocationManager
    private var currentSessionID: UUID?
    private var shouldRecord = false
    private var lastLocation: CLLocation?

    override init() {
        let manager = CLLocationManager()
        self.locationManager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
        updateAvailabilityStateIfNeeded()
    }

    func sync(with session: TrackedActivitySession) {
        guard isEligible(session) else {
            shouldRecord = false
            stopRecording(resetSession: false)
            currentSessionID = session.id
            capturedPoints = session.routePoints
            derivedDistanceMeters = session.routeDistanceMeters ?? session.distanceMeters
            captureState = .notEligible
            return
        }

        if currentSessionID != session.id {
            currentSessionID = session.id
            capturedPoints = session.routePoints
            derivedDistanceMeters = session.routeDistanceMeters ?? session.distanceMeters
            lastLocation = capturedPoints.last?.location
        }

        authorizationStatus = locationManager.authorizationStatus
        updateAvailabilityStateIfNeeded()

        switch session.lifecycleState {
        case .inProgress:
            shouldRecord = true
            beginRecordingIfPossible()
        case .paused:
            shouldRecord = false
            stopUpdatingLocationOnly()
            captureState = authorizationDenied ? .permissionDenied : .paused
        case .completed, .discarded, .planned:
            shouldRecord = false
            stopUpdatingLocationOnly()
            if authorizationDenied {
                captureState = .permissionDenied
            } else if capturedPoints.count > 1 {
                captureState = .paused
            } else {
                captureState = .idle
            }
        }
    }

    func stopRecording(resetSession: Bool = true) {
        stopUpdatingLocationOnly()
        if resetSession {
            currentSessionID = nil
            shouldRecord = false
            lastLocation = nil
            capturedPoints = []
            derivedDistanceMeters = nil
        }
    }

    var canOpenSystemSettings: Bool {
        authorizationDenied
    }

    var hasCapturedAnyPoints: Bool {
        !capturedPoints.isEmpty
    }

    var hasRecordedRoute: Bool {
        capturedPoints.count > 1
    }

    private var authorizationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    private func isEligible(_ session: TrackedActivitySession) -> Bool {
        session.environment == .outdoor && session.activityKind.supportsDistance
    }

    private func beginRecordingIfPossible() {
        guard CLLocationManager.locationServicesEnabled() else {
            captureState = .unavailable
            return
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            captureState = capturedPoints.isEmpty ? .searchingForLocation : .recording
        case .notDetermined:
            captureState = .requestingPermission
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            stopUpdatingLocationOnly()
            captureState = .permissionDenied
        @unknown default:
            stopUpdatingLocationOnly()
            captureState = .permissionDenied
        }
    }

    private func stopUpdatingLocationOnly() {
        locationManager.stopUpdatingLocation()
    }

    private func append(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return }

        if let lastLocation {
            let timeDelta = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            let incrementalDistance = max(0, location.distance(from: lastLocation))
            if timeDelta <= 0 && incrementalDistance < 2 {
                return
            }
        }

        capturedPoints.append(TrackedActivityRoutePoint(location: location))
        lastLocation = location
        derivedDistanceMeters = calculateDistance(from: capturedPoints)
        captureState = .recording
    }

    private func calculateDistance(from points: [TrackedActivityRoutePoint]) -> Double? {
        guard points.count > 1 else { return nil }
        let locations = points.map(\.location)
        var totalDistance: CLLocationDistance = 0
        for index in 1..<locations.count {
            totalDistance += max(0, locations[index].distance(from: locations[index - 1]))
        }
        return totalDistance > 0 ? totalDistance : nil
    }

    private func updateAvailabilityStateIfNeeded() {
        authorizationStatus = locationManager.authorizationStatus
        if !CLLocationManager.locationServicesEnabled() {
            captureState = .unavailable
        }
    }

    private func handleTransientFailureWhileRecording() {
        guard shouldRecord else { return }
        captureState = capturedPoints.isEmpty ? .searchingForLocation : .recording
    }
}

extension OutdoorRouteRecorder: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            updateAvailabilityStateIfNeeded()
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                if shouldRecord {
                    locationManager.startUpdatingLocation()
                    captureState = capturedPoints.isEmpty ? .searchingForLocation : .recording
                }
            } else if authorizationStatus == .denied || authorizationStatus == .restricted {
                stopUpdatingLocationOnly()
                captureState = .permissionDenied
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                append(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let clError = error as? CLError else {
                captureState = .failed("Route capture was interrupted. WorkoutTracker will keep trying while this activity remains active.")
                return
            }

            switch clError.code {
            case .locationUnknown:
                handleTransientFailureWhileRecording()
            case .denied:
                stopUpdatingLocationOnly()
                captureState = .permissionDenied
            case .network, .deferredFailed, .deferredNotUpdatingLocation, .deferredAccuracyTooLow, .deferredDistanceFiltered, .deferredCanceled:
                handleTransientFailureWhileRecording()
            default:
                captureState = .failed(clError.localizedDescription)
            }
        }
    }
}
