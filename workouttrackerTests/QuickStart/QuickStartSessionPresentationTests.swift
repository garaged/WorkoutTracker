import XCTest
@testable import workouttracker

final class QuickStartSessionPresentationTests: XCTestCase {
    private let epoch = UUID()

    private func sample(_ seconds: Double, wallOffset: Double = 0, epoch: UUID? = nil) -> QuickStartClockSample {
        QuickStartClockSample(
            wall: Date(timeIntervalSince1970: 1_000 + seconds + wallOffset),
            uptime: 500 + seconds,
            epoch: epoch ?? self.epoch
        )
    }

    private func started(styleRaw: String = QuickStartStyle.hiit.rawValue) throws -> QuickStartTimingPayload {
        let timing = try QuickStartTimingState().applying(
            .start,
            id: UUID(),
            expectedRevision: 0,
            at: sample(0)
        )
        return try QuickStartTimingPayload(styleRaw: styleRaw, timing: timing)
    }

    func testRunningPresentationUsesPersistedTimerAndStyleIdentity() throws {
        let presentation = try QuickStartSessionPresentation(payload: started(), at: sample(37))

        XCTAssertEqual(presentation.styleRaw, QuickStartStyle.hiit.rawValue)
        XCTAssertEqual(presentation.style, .hiit)
        XCTAssertEqual(presentation.phase, .running)
        XCTAssertEqual(presentation.timingStatus, .elapsed(37))
        XCTAssertEqual(presentation.primaryAction, .pause)
    }

    func testPausedPresentationDoesNotAccumulateLaterWallTime() throws {
        let running = try started(styleRaw: QuickStartStyle.cardio.rawValue)
        let pausedTiming = try running.timing.applying(
            .pause,
            id: UUID(),
            expectedRevision: running.timing.revision,
            at: sample(60)
        )
        let payload = try QuickStartTimingPayload(styleRaw: running.styleRaw, timing: pausedTiming)
        let presentation = try QuickStartSessionPresentation(payload: payload, at: sample(9_000))

        XCTAssertEqual(presentation.timingStatus, .elapsed(60))
        XCTAssertEqual(presentation.primaryAction, .resume)
    }

    func testClockDiscontinuityBecomesDedicatedRecoveryPresentation() throws {
        let presentation = try QuickStartSessionPresentation(
            payload: started(),
            at: sample(30, wallOffset: 600)
        )

        XCTAssertEqual(presentation.phase, .running)
        XCTAssertEqual(presentation.timingStatus, .recoveryRequired)
        XCTAssertEqual(presentation.primaryAction, .resolveRecovery)
    }

    func testUnknownStyleIdentityIsPreservedWithoutSubstitution() throws {
        let raw = "future_training_style"
        let running = try started(styleRaw: raw)
        let completedTiming = try running.timing.applying(
            .finish,
            id: UUID(),
            expectedRevision: running.timing.revision,
            at: sample(20)
        )
        let payload = try QuickStartTimingPayload(styleRaw: raw, timing: completedTiming)
        let presentation = try QuickStartSessionPresentation(payload: payload, at: sample(50))

        XCTAssertEqual(presentation.styleRaw, raw)
        XCTAssertNil(presentation.style)
        XCTAssertEqual(presentation.phase, .completed)
        XCTAssertEqual(presentation.timingStatus, .elapsed(20))
        XCTAssertEqual(presentation.primaryAction, .done)
    }

    func testInvalidClockRemainsADataErrorInsteadOfRecoveryChoice() throws {
        let invalid = QuickStartClockSample(wall: Date(), uptime: .nan, epoch: epoch)
        XCTAssertThrowsError(try QuickStartSessionPresentation(payload: started(), at: invalid)) {
            XCTAssertEqual($0 as? QuickStartTimingError, .invalidClock)
        }
    }
}
