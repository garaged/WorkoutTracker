import XCTest
@testable import workouttracker

final class QuickStartTimingPayloadTests: XCTestCase {
    private func running() throws -> QuickStartTimingState {
        try QuickStartTimingState().applying(.start, id: UUID(), expectedRevision: 0,
            at: QuickStartClockSample(wall: Date(timeIntervalSince1970: 1000), uptime: 100, epoch: UUID()))
    }

    private func mutated(_ change: (inout [String: Any]) -> Void) throws -> Data {
        let payload = try QuickStartTimingPayload(styleRaw: "cardio", timing: running())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        change(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }

    func testKnownStyleAndTimingRoundTrip() throws {
        let payload = try QuickStartTimingPayload(styleRaw: "cardio", timing: running())
        let decoded = try JSONDecoder().decode(QuickStartTimingPayload.self, from: JSONEncoder().encode(payload))
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoded.style, .cardio)
    }

    func testUnknownStyleSurvivesWithoutSubstitution() throws {
        let payload = try QuickStartTimingPayload(styleRaw: "future_style", timing: running())
        let decoded = try JSONDecoder().decode(QuickStartTimingPayload.self, from: JSONEncoder().encode(payload))
        XCTAssertEqual(decoded.styleRaw, "future_style")
        XCTAssertNil(decoded.style)
    }

    func testUnsupportedVersionIsRejected() throws {
        let data = try mutated { $0["version"] = 2 }
        XCTAssertThrowsError(try JSONDecoder().decode(QuickStartTimingPayload.self, from: data))
    }

    func testBlankStyleIsRejectedAtCreationAndDecode() throws {
        XCTAssertThrowsError(try QuickStartTimingPayload(styleRaw: "  ", timing: running()))
        let data = try mutated { $0["styleRaw"] = "" }
        XCTAssertThrowsError(try JSONDecoder().decode(QuickStartTimingPayload.self, from: data))
    }

    func testInvalidTimingStateIsRejectedAtPersistenceBoundary() throws {
        let corruptions: [(inout [String: Any]) -> Void] = [
            { $0["accumulated"] = -1 },
            { $0.removeValue(forKey: "anchor") },
            { $0["revision"] = 9 },
            { $0["phase"] = "paused" },
            { state in
                let commands = state["appliedCommands"] as! [[String: Any]]
                state["appliedCommands"] = commands + commands
                state["revision"] = 2
            },
            { state in
                var commands = state["appliedCommands"] as! [[String: Any]]
                commands[0]["action"] = "resume"
                state["appliedCommands"] = commands
            }
        ]
        for (index, corruption) in corruptions.enumerated() {
            let data = try mutated { json in
                var state = json["timing"] as! [String: Any]
                corruption(&state)
                json["timing"] = state
            }
            XCTAssertThrowsError(try JSONDecoder().decode(QuickStartTimingPayload.self, from: data), "corruption \(index)")
        }
    }

    func testOldStructurallyValidAnchorIsPreservedForRecoveryReview() throws {
        let state = try running()
        let payload = try QuickStartTimingPayload(styleRaw: "cardio", timing: state)
        let restored = try JSONDecoder().decode(QuickStartTimingPayload.self, from: JSONEncoder().encode(payload))
        XCTAssertEqual(restored.timing, state)
        XCTAssertThrowsError(try restored.timing.elapsed(at:
            QuickStartClockSample(wall: Date(timeIntervalSince1970: 100000), uptime: 10, epoch: UUID())))
    }
}
