import XCTest
@testable import workouttracker

final class RestTimerEngineTests: XCTestCase {
    func test_startBeginsInCountdownMode() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 90, now: now)
        let snapshot = engine.snapshot(now: now)

        XCTAssertEqual(snapshot.mode, .countdown)
        XCTAssertEqual(snapshot.remainingSeconds, 90)
        XCTAssertEqual(snapshot.displaySeconds, 90)
        XCTAssertFalse(snapshot.shouldPlayCompletionCue)
    }

    func test_snapshotBeforeZeroRemainsCountdown() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 60, now: now)
        let snapshot = engine.snapshot(now: now.addingTimeInterval(20))

        XCTAssertEqual(snapshot.mode, .countdown)
        XCTAssertEqual(snapshot.remainingSeconds, 40)
        XCTAssertEqual(snapshot.overdueSeconds, 0)
    }

    func test_snapshotExactlyAtZeroEntersReadyAndCuesOnce() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 60, now: now)

        let first = engine.snapshot(now: now.addingTimeInterval(60))
        let second = engine.snapshot(now: now.addingTimeInterval(60))

        XCTAssertEqual(first.mode, .ready)
        XCTAssertEqual(first.displaySeconds, 0)
        XCTAssertTrue(first.shouldPlayCompletionCue)
        XCTAssertFalse(second.shouldPlayCompletionCue)
    }

    func test_snapshotAfterZeroEntersOverdue() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 60, now: now)
        let snapshot = engine.snapshot(now: now.addingTimeInterval(75))

        XCTAssertEqual(snapshot.mode, .overdue)
        XCTAssertEqual(snapshot.remainingSeconds, 0)
        XCTAssertEqual(snapshot.overdueSeconds, 15)
        XCTAssertEqual(snapshot.displaySeconds, -15)
    }

    func test_extendWhileCountdownAddsTime() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 60, now: now)
        engine.extend(by: 15, now: now.addingTimeInterval(10))

        let snapshot = engine.snapshot(now: now.addingTimeInterval(10))
        XCTAssertEqual(snapshot.mode, .countdown)
        XCTAssertEqual(snapshot.remainingSeconds, 65)
    }

    func test_extendWhileOverdueCanReturnToCountdownAndRearmCue() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 30, now: now)
        _ = engine.snapshot(now: now.addingTimeInterval(40))
        engine.extend(by: 20, now: now.addingTimeInterval(40))

        let countdown = engine.snapshot(now: now.addingTimeInterval(40))
        let ready = engine.snapshot(now: now.addingTimeInterval(50))

        XCTAssertEqual(countdown.mode, .countdown)
        XCTAssertEqual(countdown.remainingSeconds, 10)
        XCTAssertTrue(ready.shouldPlayCompletionCue)
    }

    func test_resolveForNextActionClearsTimer() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 60, now: now)
        engine.resolveForNextAction(now: now.addingTimeInterval(5))

        XCTAssertEqual(engine.snapshot(now: now.addingTimeInterval(5)), .inactive)
    }

    func test_completionCueTriggersOnceOnlyWhileOverdue() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 10, now: now)

        let first = engine.snapshot(now: now.addingTimeInterval(11))
        let second = engine.snapshot(now: now.addingTimeInterval(20))

        XCTAssertTrue(first.shouldPlayCompletionCue)
        XCTAssertFalse(second.shouldPlayCompletionCue)
    }

    func test_zeroOrNegativePlannedRestClearsGracefully() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 0, now: now)
        XCTAssertEqual(engine.snapshot(now: now), .inactive)

        engine.start(plannedRestSeconds: -30, now: now)
        XCTAssertEqual(engine.snapshot(now: now), .inactive)
    }

    func test_pauseAndResumePreserveRemainingTime() {
        var engine = RestTimerEngine()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.start(plannedRestSeconds: 60, now: now)
        engine.pause(now: now.addingTimeInterval(20))

        let paused = engine.snapshot(now: now.addingTimeInterval(40))
        XCTAssertEqual(paused.mode, .countdown)
        XCTAssertTrue(paused.isPaused)
        XCTAssertEqual(paused.remainingSeconds, 40)

        engine.resume(now: now.addingTimeInterval(40))
        let resumed = engine.snapshot(now: now.addingTimeInterval(50))
        XCTAssertEqual(resumed.remainingSeconds, 30)
    }
}
