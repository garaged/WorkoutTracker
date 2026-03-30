import XCTest
@testable import workouttracker

final class IntentLaunchBridgeTests: XCTestCase {
    func test_urlForSessionExercise_buildsCanonicalURL() {
        let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let exerciseID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let url = IntentLaunchBridge.url(for: .sessionExercise(sessionID: sessionID, exerciseID: exerciseID))

        XCTAssertEqual(
            url?.absoluteString,
            "workouttracker://session/11111111-1111-1111-1111-111111111111/exercise/22222222-2222-2222-2222-222222222222"
        )
    }

    func test_stageAndClearPendingURL_roundTripsRoute() {
        let defaults = UserDefaults(suiteName: #function)!
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let sessionID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        IntentLaunchBridge.stage(route: .sessionRest(sessionID: sessionID), defaults: defaults)

        XCTAssertEqual(
            IntentLaunchBridge.peekPendingURL(defaults: defaults)?.absoluteString,
            "workouttracker://session/33333333-3333-3333-3333-333333333333/rest"
        )

        IntentLaunchBridge.clearPendingURL(defaults: defaults)
        XCTAssertNil(IntentLaunchBridge.peekPendingURL(defaults: defaults))
    }
}
