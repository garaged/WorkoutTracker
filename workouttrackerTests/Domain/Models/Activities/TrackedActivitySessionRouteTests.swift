import XCTest
import CoreLocation
@testable import workouttracker

final class TrackedActivitySessionRouteTests: XCTestCase {
    func testRoutePoints_roundTripAndDistanceIsDerived() throws {
        let points = [
            TrackedActivityRoutePoint(location: CLLocation(latitude: 37.3317, longitude: -122.0301)),
            TrackedActivityRoutePoint(location: CLLocation(latitude: 37.3322, longitude: -122.0296)),
            TrackedActivityRoutePoint(location: CLLocation(latitude: 37.3326, longitude: -122.0290))
        ]

        let session = TrackedActivitySession(
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: 1_200),
            routePoints: points
        )

        XCTAssertEqual(session.routePointCount, 3)
        XCTAssertTrue(session.hasRecordedRoute)
        XCTAssertEqual(session.routePoints.count, 3)

        let routeDistance = try XCTUnwrap(session.routeDistanceMeters)
        XCTAssertGreaterThan(routeDistance, 0)
    }
}
