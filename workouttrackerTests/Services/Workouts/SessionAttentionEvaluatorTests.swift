import XCTest
@testable import workouttracker

final class SessionAttentionEvaluatorTests: XCTestCase {
    private var calendar: Calendar!
    private var evaluator: SessionAttentionEvaluator!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        evaluator = SessionAttentionEvaluator(calendar: calendar)
    }

    func test_sameDayUnfinishedSession_isFresh() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(startedAt: now)

        let result = evaluator.evaluate(session: session, owningDay: now, now: now)

        XCTAssertEqual(result.state, .fresh)
        XCTAssertFalse(result.isStale)
        XCTAssertFalse(result.shouldShowRecoveryPrompt)
    }

    func test_priorDayUnfinishedSession_needsPrompt() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let session = WorkoutSession(startedAt: yesterday)

        let result = evaluator.evaluate(session: session, owningDay: yesterday, now: now)

        XCTAssertEqual(result.state, .staleNeedsPrompt)
        XCTAssertTrue(result.isStale)
        XCTAssertTrue(result.shouldShowRecoveryPrompt)
    }

    func test_dismissedToday_staleSession_isSuppressed() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let session = WorkoutSession(startedAt: yesterday)
        session.dismissedStalePromptAt = now

        let result = evaluator.evaluate(session: session, owningDay: yesterday, now: now)

        XCTAssertEqual(result.state, .staleSuppressed)
        XCTAssertTrue(result.isStale)
        XCTAssertFalse(result.shouldShowRecoveryPrompt)
    }
}
