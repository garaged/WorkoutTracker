import Foundation
import CoreLocation

struct TrackedActivityHealthExportPayload {
    struct RouteLocation {
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees
        let altitude: CLLocationDistance
        let horizontalAccuracy: CLLocationAccuracy
        let verticalAccuracy: CLLocationAccuracy
        let course: CLLocationDirection
        let speed: CLLocationSpeed
        let timestamp: Date

        init(location: CLLocation) {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.altitude = location.altitude
            self.horizontalAccuracy = location.horizontalAccuracy
            self.verticalAccuracy = location.verticalAccuracy
            self.course = location.course
            self.speed = location.speed
            self.timestamp = location.timestamp
        }

        var clLocation: CLLocation {
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                altitude: altitude,
                horizontalAccuracy: horizontalAccuracy,
                verticalAccuracy: verticalAccuracy,
                course: course,
                speed: speed,
                timestamp: timestamp
            )
        }
    }

    let sessionID: UUID
    let lifecycleState: TrackedActivityLifecycleState
    let startedAt: Date?
    let endedAt: Date?
    let activityKind: TrackedActivityKind
    let environment: ActivityEnvironment
    let activeEnergyKilocalories: Double?
    let distanceMeters: Double?
    let hasRecordedRoute: Bool
    let routePointCount: Int
    let routeLocations: [RouteLocation]

    static func make(from session: TrackedActivitySession) -> Self {
        Self(
            sessionID: session.id,
            lifecycleState: session.lifecycleState,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            activityKind: session.activityKind,
            environment: session.environment,
            activeEnergyKilocalories: session.activeEnergyKilocalories,
            distanceMeters: session.distanceMeters,
            hasRecordedRoute: session.hasRecordedRoute,
            routePointCount: session.routePointCount,
            routeLocations: session.routePoints.map { RouteLocation(location: $0.location) }
        )
    }
}
