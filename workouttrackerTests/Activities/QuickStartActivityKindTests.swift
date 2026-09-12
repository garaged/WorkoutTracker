import XCTest
@testable import workouttracker

final class QuickStartActivityKindTests: XCTestCase {
    func testUnknownStoredKindHasNeutralCapabilitiesAndPreservesRawID() {
        let session = TrackedActivitySession(activityKind: .yoga)
        session.activityKindRaw = "future_kind"
        XCTAssertEqual(session.activityKind.rawValue, "generic")
        XCTAssertFalse(session.activityKind.supportsDistance)
        XCTAssertFalse(session.activityKind.supportsSteps)
        XCTAssertFalse(session.activityKind.supportsPace)
        XCTAssertEqual(session.activityKind.defaultEnvironment, .unspecified)
        XCTAssertEqual(session.activityKindRaw, "future_kind")
        XCTAssertEqual(session.summary.highlightedMetricKinds, [.duration])
    }
}
