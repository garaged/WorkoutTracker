import XCTest
@testable import workouttracker

final class ConsistencyCalculatorTests: XCTestCase {
    func test_summary_computesActiveWeeks_average_andCompletionRate() {
        let calendar = makeCalendar()
        let calculator = ConsistencyCalculator(calendar: calendar)

        // Start exactly at a Monday week boundary.
        let base = TestSupport.date(2026, 3, 2, 0, 0)

        let window = DateInterval(
            start: base,
            end: calendar.date(byAdding: .day, value: 27, to: base)!
        )

        let sessions = [
            session(startedAt: calendar.date(byAdding: .day, value: 0, to: base)!, wasCompleted: true),
            session(startedAt: calendar.date(byAdding: .day, value: 2, to: base)!, wasCompleted: true),
            session(startedAt: calendar.date(byAdding: .day, value: 10, to: base)!, wasCompleted: false),
            session(startedAt: calendar.date(byAdding: .day, value: 17, to: base)!, wasCompleted: true)
        ]

        let summary = calculator.summary(from: sessions, window: window)

        XCTAssertEqual(summary.activeWeeks, 2)
        XCTAssertEqual(summary.totalWeeks, 4)
        XCTAssertEqual(summary.averageWorkoutsPerWeek, 0.75, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(summary.completionRate), 0.75, accuracy: 0.0001)
        XCTAssertEqual(summary.dataAvailability, .full)
    }

    func test_summary_returnsInsufficient_whenWindowHasNoSessions() {
        let calculator = ConsistencyCalculator(calendar: makeCalendar())
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let window = DateInterval(start: base, duration: 7 * 24 * 60 * 60)

        let summary = calculator.summary(from: [], window: window)

        XCTAssertEqual(summary.activeWeeks, 0)
        XCTAssertNil(summary.completionRate)
        XCTAssertEqual(summary.dataAvailability, .insufficient)
    }

    private func session(startedAt: Date, wasCompleted: Bool) -> SessionAnalyticsSample {
        SessionAnalyticsSample(
            id: UUID(),
            startedAt: startedAt,
            wasCompleted: wasCompleted,
            completedExerciseCount: wasCompleted ? 3 : 0,
            durationSeconds: nil,
            segmentsPresent: [.main]
        )
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }
}
