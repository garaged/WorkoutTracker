import XCTest
@testable import workouttracker

final class TrackedActivityRecoveryPlannerTests: XCTestCase {
    private var calendar: Calendar!
    private var planner: TrackedActivityRecoveryPlanner!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        planner = TrackedActivityRecoveryPlanner(calendar: calendar)
    }

    func test_sameDayActiveSession_withBackgroundTransition_isInterrupted() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let start = now.addingTimeInterval(-900)
        let session = TrackedActivitySession(
            createdAt: start,
            updatedAt: start,
            startedAt: start,
            endedAt: nil,
            activeIntervalStartedAt: start,
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .inProgress,
            totals: TrackedActivityTotals(elapsedDuration: 0),
            lastResumedAt: start,
            lastBackgroundedAt: now.addingTimeInterval(-60)
        )

        XCTAssertEqual(planner.recoveryState(for: session, now: now), .interrupted)
    }

    func test_previousDayPausedSession_needsPrompt() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: now)!
        let session = TrackedActivitySession(
            createdAt: previousDay,
            updatedAt: previousDay,
            startedAt: previousDay,
            endedAt: nil,
            activeIntervalStartedAt: nil,
            activityKind: .walking,
            environment: .outdoor,
            lifecycleState: .paused,
            totals: TrackedActivityTotals(elapsedDuration: 900),
            lastResumedAt: previousDay
        )

        XCTAssertEqual(planner.recoveryState(for: session, now: now), .staleNeedsPrompt)
    }

    func test_previousDayDismissedSession_isSuppressedForToday() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: now)!
        let session = TrackedActivitySession(
            createdAt: previousDay,
            updatedAt: previousDay,
            startedAt: previousDay,
            endedAt: nil,
            activeIntervalStartedAt: nil,
            activityKind: .walking,
            environment: .outdoor,
            lifecycleState: .paused,
            totals: TrackedActivityTotals(elapsedDuration: 900),
            lastResumedAt: previousDay,
            dismissedRecoveryPromptAt: now
        )

        XCTAssertEqual(planner.recoveryState(for: session, now: now), .staleSuppressed)
    }

    func test_completedSession_withFailedHealthExport_surfacesFollowUp() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1_800)
        let session = TrackedActivitySession(
            createdAt: start,
            updatedAt: end,
            startedAt: start,
            endedAt: end,
            activeIntervalStartedAt: nil,
            activityKind: .walking,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: end.timeIntervalSince(start)),
            healthKitExportState: .failed,
            healthKitExportAttemptedAt: end,
            healthKitExportFailureMessage: "Save failed"
        )

        XCTAssertEqual(planner.healthFollowUpState(for: session), .exportFailed)
    }

    func test_completedSession_withLocalChangesAfterExport_surfacesFollowUp() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1_200)
        let session = TrackedActivitySession(
            createdAt: start,
            updatedAt: end,
            startedAt: start,
            endedAt: end,
            activeIntervalStartedAt: nil,
            activityKind: .walking,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(elapsedDuration: end.timeIntervalSince(start)),
            healthKitExportState: .exported,
            healthKitExportAttemptedAt: end,
            healthKitExportSucceededAt: end,
            hasLocalChangesSinceHealthKitExport: true
        )

        XCTAssertEqual(planner.healthFollowUpState(for: session), .savedWithLocalChanges)
    }
}
