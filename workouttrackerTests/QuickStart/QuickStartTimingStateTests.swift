import XCTest
@testable import workouttracker

final class QuickStartTimingStateTests: XCTestCase {
    private let epoch = UUID()
    private func sample(_ seconds: Double, wallOffset: Double = 0, epoch: UUID? = nil) -> QuickStartClockSample {
        QuickStartClockSample(wall: Date(timeIntervalSince1970: 1_000 + seconds + wallOffset),
                              uptime: 500 + seconds, epoch: epoch ?? self.epoch)
    }
    private func apply(_ state: QuickStartTimingState, _ action: QuickStartTimingState.Action,
                       at seconds: Double, id: UUID = UUID()) throws -> QuickStartTimingState {
        try state.applying(action, id: id, expectedRevision: state.revision, at: sample(seconds))
    }
    func testPauseExcludesTimeAndFinishIsIdempotent() throws {
        var state = try apply(QuickStartTimingState(), .start, at: 0)
        state = try apply(state, .pause, at: 60)
        XCTAssertEqual(try state.elapsed(at: sample(90)), 60, accuracy: 0.001)
        state = try apply(state, .resume, at: 90)
        state = try apply(state, .finish, at: 110)
        XCTAssertEqual(state.phase, .completed)
        XCTAssertEqual(try state.elapsed(at: sample(200)), 80, accuracy: 0.001)
        XCTAssertEqual(try apply(state, .finish, at: 200), state)
    }
    func testDuplicateCommandIgnoresOldRevisionWithoutCountingTwice() throws {
        let id = UUID()
        let state = try apply(QuickStartTimingState(), .start, at: 0, id: id)
        let repeated = try state.applying(.start, id: id, expectedRevision: 0, at: sample(20))
        XCTAssertEqual(repeated, state)
        XCTAssertEqual(state.revision, 1)
    }
    func testReusingCommandIdentityForDifferentActionFails() throws {
        let id = UUID()
        let state = try apply(QuickStartTimingState(), .start, at: 0, id: id)
        XCTAssertThrowsError(try state.applying(.finish, id: id, expectedRevision: state.revision, at: sample(10))) {
            XCTAssertEqual($0 as? QuickStartTimingError, .commandIdentityReused)
        }
    }
    func testStaleCommandCannotOverwriteNewerState() throws {
        let state = try apply(QuickStartTimingState(), .start, at: 0)
        XCTAssertThrowsError(try state.applying(.pause, id: UUID(), expectedRevision: 0, at: sample(10))) {
            XCTAssertEqual($0 as? QuickStartTimingError, .staleRevision)
        }
        XCTAssertEqual(state.phase, .running)
    }
    func testProposedTransitionDoesNotMutateCommittedValue() throws {
        let committed = try apply(QuickStartTimingState(), .start, at: 0)
        let proposed = try apply(committed, .finish, at: 45)
        // A persistence adapter publishes proposed only after its write succeeds.
        XCTAssertEqual(committed.phase, .running)
        XCTAssertEqual(proposed.phase, .completed)
        XCTAssertEqual(proposed.accumulated, 45, accuracy: 0.001)
    }
    func testRoundTripAndCrossLaunchRecoveryUsePersistedWallAnchor() throws {
        let original = try apply(QuickStartTimingState(), .start, at: 0)
        let decoded = try JSONDecoder().decode(QuickStartTimingState.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(try decoded.elapsed(at: sample(75, epoch: UUID())), 75, accuracy: 0.001)
    }
    func testClockDiscontinuityRequiresReview() throws {
        let state = try apply(QuickStartTimingState(), .start, at: 0)
        XCTAssertThrowsError(try state.elapsed(at: sample(30, wallOffset: 600))) {
            XCTAssertEqual($0 as? QuickStartTimingError, .recoveryRequired)
        }
        XCTAssertThrowsError(try state.elapsed(at: sample(-20, epoch: UUID())))
        XCTAssertThrowsError(try state.elapsed(at: sample(43_201, epoch: UUID())))
    }
    func testRecoveryCanPauseAtLastSavedTimeThenResumeCleanly() throws {
        var state = try apply(QuickStartTimingState(), .start, at: 0)
        let newEpoch = UUID()
        let recoverySample = sample(50_000, epoch: newEpoch)
        XCTAssertThrowsError(try state.elapsed(at: recoverySample)) {
            XCTAssertEqual($0 as? QuickStartTimingError, .recoveryRequired)
        }

        state = try state.resolvingRecovery(
            .pauseAtLastSavedTime,
            id: UUID(),
            expectedRevision: state.revision,
            at: recoverySample
        )
        XCTAssertEqual(state.phase, .paused)
        XCTAssertEqual(state.accumulated, 0)
        XCTAssertNil(state.anchor)

        state = try state.applying(.resume, id: UUID(), expectedRevision: state.revision, at: recoverySample)
        state = try state.applying(
            .finish,
            id: UUID(),
            expectedRevision: state.revision,
            at: sample(50_010, epoch: newEpoch)
        )
        XCTAssertEqual(state.accumulated, 10, accuracy: 0.001)
    }
    func testRecoveryCanFinishWithoutCountingUncertainGapAndRetryIsIdempotent() throws {
        let running = try apply(QuickStartTimingState(), .start, at: 0)
        let command = UUID()
        let recovered = try running.resolvingRecovery(
            .finishAtLastSavedTime,
            id: command,
            expectedRevision: running.revision,
            at: sample(50_000, epoch: UUID())
        )
        XCTAssertEqual(recovered.phase, .completed)
        XCTAssertEqual(recovered.accumulated, 0)
        XCTAssertEqual(recovered.revision, 2)
        XCTAssertEqual(
            try recovered.resolvingRecovery(
                .finishAtLastSavedTime,
                id: command,
                expectedRevision: running.revision,
                at: sample(60_000, epoch: UUID())
            ),
            recovered
        )
    }
    func testRecoveryResolutionRequiresRunningStateAndCurrentRevision() throws {
        XCTAssertThrowsError(
            try QuickStartTimingState().resolvingRecovery(
                .pauseAtLastSavedTime,
                id: UUID(),
                expectedRevision: 0,
                at: sample(0)
            )
        ) {
            XCTAssertEqual($0 as? QuickStartTimingError, .invalidTransition)
        }
        let running = try apply(QuickStartTimingState(), .start, at: 0)
        XCTAssertThrowsError(
            try running.resolvingRecovery(
                .finishAtLastSavedTime,
                id: UUID(),
                expectedRevision: 0,
                at: sample(50_000, epoch: UUID())
            )
        ) {
            XCTAssertEqual($0 as? QuickStartTimingError, .staleRevision)
        }
    }
    func testNonFiniteClockIsRejected() throws {
        let invalid = QuickStartClockSample(wall: Date(), uptime: .nan, epoch: epoch)
        XCTAssertThrowsError(try QuickStartTimingState().applying(.start, id: UUID(), expectedRevision: 0, at: invalid))
    }
    func testResumeCannotReopenFinishedTimer() throws {
        var state = try apply(QuickStartTimingState(), .start, at: 0)
        state = try apply(state, .finish, at: 1)
        XCTAssertThrowsError(try apply(state, .resume, at: 2))
    }
    func testDeterministicSequencesNeverCountPausedTime() throws {
        for length in 1...40 {
            var state = try apply(QuickStartTimingState(), .start, at: 0)
            var wall = 0.0
            var expected = 0.0
            for step in 1...length {
                let running = Double((step * 17) % 31)
                wall += running
                expected += running
                state = try apply(state, .pause, at: wall)
                wall += Double((step * 11) % 29)
                state = try apply(state, .resume, at: wall)
            }
            state = try apply(state, .finish, at: wall)
            XCTAssertEqual(state.accumulated, expected, accuracy: 0.001)
        }
    }
}
