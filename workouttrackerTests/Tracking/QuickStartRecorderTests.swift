import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class QuickStartRecorderTests: XCTestCase {
    private let epoch = UUID()
    private func clock(_ seconds: Double) -> QuickStartClockSample {
        QuickStartClockSample(wall: Date(timeIntervalSince1970: 1000 + seconds), uptime: seconds, epoch: epoch)
    }
    private func container() throws -> ModelContainer {
        let schema = Schema([TrackedActivitySession.self, WorkoutSession.self,
                             WorkoutSessionExercise.self, WorkoutSetLog.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }
    private func payload(_ session: TrackedActivitySession) throws -> QuickStartTimingPayload {
        try JSONDecoder().decode(QuickStartTimingPayload.self, from: XCTUnwrap(session.quickStartTimingBlob))
    }

    func testStartCommitsOneCanonicalRecordAndRetryKeepsIdentity() throws {
        let store = try container(), id = UUID()
        let context = ModelContext(store)
        let recorder = QuickStartRecorder()
        let started = try recorder.start(style: .cardio, id: id, at: clock(0), context: context)
        let retried = try recorder.start(style: .cardio, id: id, at: clock(2), context: context)
        XCTAssertEqual(started.id, retried.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TrackedActivitySession>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
        XCTAssertEqual(started.lifecycleState, .inProgress)
        XCTAssertEqual(try payload(started).style, .cardio)
        XCTAssertNil(started.distanceMeters)
        XCTAssertNil(started.activeEnergyKilocalories)
        XCTAssertNil(started.stepCount)
    }

    func testPauseResumeFinishAndReopenPreserveEightyActiveSeconds() throws {
        let store = try container(), context = ModelContext(store)
        let recorder = QuickStartRecorder()
        let session = try recorder.start(style: .hiit, id: UUID(), at: clock(0), context: context)
        try recorder.apply(.pause, to: session, id: UUID(), expectedRevision: 1, at: clock(60), context: context)
        try recorder.apply(.resume, to: session, id: UUID(), expectedRevision: 2, at: clock(90), context: context)
        let finishID = UUID()
        try recorder.apply(.finish, to: session, id: finishID, expectedRevision: 3, at: clock(110), context: context)
        try recorder.apply(.finish, to: session, id: finishID, expectedRevision: 3, at: clock(120), context: context)
        let reopened = ModelContext(store)
        let records = try reopened.fetch(FetchDescriptor<TrackedActivitySession>())
        XCTAssertEqual(records.count, 1)
        let restored = try XCTUnwrap(records.first)
        XCTAssertEqual(restored.id, session.id)
        XCTAssertEqual(restored.lifecycleState, .completed)
        XCTAssertEqual(restored.elapsedDuration, 80, accuracy: 0.001)
        XCTAssertEqual(try payload(restored).timing.accumulated, 80, accuracy: 0.001)
        XCTAssertNil(restored.activeIntervalStartedAt)
        XCTAssertEqual(restored.endedAt, clock(110).wall)
    }

    func testFailedStartLeavesNoInsertedRecordAndCanRetry() throws {
        enum Fault: Error { case disk }
        let store = try container(), context = ModelContext(store), id = UUID()
        let failing = QuickStartRecorder(save: { _ in throw Fault.disk })
        XCTAssertThrowsError(try failing.start(style: .cardio, id: id, at: clock(0), context: context))
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TrackedActivitySession>()), 0)
        _ = try QuickStartRecorder().start(style: .cardio, id: id, at: clock(1), context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TrackedActivitySession>()), 1)
    }

    func testFailedFinishRestoresCommittedStateBeforeRetry() throws {
        enum Fault: Error { case disk }
        let store = try container(), context = ModelContext(store)
        let recorder = QuickStartRecorder()
        let session = try recorder.start(style: .yoga, id: UUID(), at: clock(0), context: context)
        let before = session.quickStartTimingBlob, command = UUID()
        let failing = QuickStartRecorder(save: { _ in throw Fault.disk })
        XCTAssertThrowsError(try failing.apply(.finish, to: session, id: command,
            expectedRevision: 1, at: clock(45), context: context))
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(session.quickStartTimingBlob, before)
        XCTAssertEqual(session.lifecycleState, .inProgress)
        XCTAssertNil(session.endedAt)
        try recorder.apply(.finish, to: session, id: command, expectedRevision: 1, at: clock(45), context: context)
        XCTAssertEqual(session.elapsedDuration, 45, accuracy: 0.001)
    }

    func testExplicitRecoveryFinishesWithoutCountingUncertainGap() throws {
        let store = try container(), context = ModelContext(store)
        let recorder = QuickStartRecorder()
        let session = try recorder.start(style: .other, id: UUID(), at: clock(0), context: context)
        let recoveryClock = QuickStartClockSample(
            wall: Date(timeIntervalSince1970: 51_000),
            uptime: 1,
            epoch: UUID()
        )
        XCTAssertThrowsError(
            try recorder.apply(
                .finish,
                to: session,
                id: UUID(),
                expectedRevision: 1,
                at: recoveryClock,
                context: context
            )
        ) {
            XCTAssertEqual($0 as? QuickStartTimingError, .recoveryRequired)
        }

        try recorder.resolveRecovery(
            .finishAtLastSavedTime,
            for: session,
            id: UUID(),
            expectedRevision: 1,
            at: recoveryClock,
            context: context
        )
        XCTAssertEqual(session.lifecycleState, .completed)
        XCTAssertEqual(session.elapsedDuration, 0)
        XCTAssertEqual(try payload(session).timing.phase, .completed)
        XCTAssertEqual(try payload(session).timing.revision, 2)
    }

    func testFailedRecoveryRestoresCommittedRunningState() throws {
        enum Fault: Error { case disk }
        let store = try container(), context = ModelContext(store)
        let session = try QuickStartRecorder().start(
            style: .mobilityStretching,
            id: UUID(),
            at: clock(0),
            context: context
        )
        let before = session.quickStartTimingBlob
        let recoveryClock = QuickStartClockSample(
            wall: Date(timeIntervalSince1970: 51_000),
            uptime: 1,
            epoch: UUID()
        )
        let failing = QuickStartRecorder(save: { _ in throw Fault.disk })

        XCTAssertThrowsError(
            try failing.resolveRecovery(
                .pauseAtLastSavedTime,
                for: session,
                id: UUID(),
                expectedRevision: 1,
                at: recoveryClock,
                context: context
            )
        )
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(session.quickStartTimingBlob, before)
        XCTAssertEqual(session.lifecycleState, .inProgress)
        XCTAssertEqual(try payload(session).timing.phase, .running)
    }

    func testActiveStrengthOrTrackedSessionBlocksNewStart() throws {
        let store = try container(), context = ModelContext(store)
        let strength = WorkoutSession()
        context.insert(strength)
        try context.save()
        XCTAssertThrowsError(try QuickStartRecorder().start(style: .cardio, id: UUID(), at: clock(0), context: context)) {
            XCTAssertEqual($0 as? QuickStartRecorder.RecordingError, .activeSessionConflict([strength.id]))
        }
        strength.status = .completed
        strength.endedAt = clock(0).wall
        try context.save()
        let activity = try QuickStartRecorder().start(style: .cardio, id: UUID(), at: clock(1), context: context)
        XCTAssertThrowsError(try QuickStartRecorder().start(style: .yoga, id: UUID(), at: clock(2), context: context)) {
            XCTAssertEqual($0 as? QuickStartRecorder.RecordingError, .activeSessionConflict([activity.id]))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TrackedActivitySession>()), 1)
    }

    func testDirtyContextIsNotSavedOrRolledBackByQuickStart() throws {
        let store = try container(), context = ModelContext(store)
        let draft = WorkoutSession()
        context.insert(draft)
        XCTAssertThrowsError(try QuickStartRecorder().start(style: .cardio, id: UUID(), at: clock(0), context: context)) {
            XCTAssertEqual($0 as? QuickStartRecorder.RecordingError, .pendingChanges)
        }
        XCTAssertTrue(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TrackedActivitySession>()), 0)
    }
}
