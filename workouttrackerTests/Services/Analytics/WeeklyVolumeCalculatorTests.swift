import XCTest
@testable import workouttracker

final class WeeklyVolumeCalculatorTests: XCTestCase {
    func test_weeklySummaries_groupsSamplesByWeek_andComputesTotals() {
        let calendar = makeCalendar()
        let calculator = WeeklyVolumeCalculator(calendar: calendar)
        let exerciseID = UUID()

        let samples = [
            sample(exerciseID: exerciseID, dayOffset: 0, weight: 100, reps: 5, sessionID: UUID(), segment: .main),
            sample(exerciseID: exerciseID, dayOffset: 1, weight: 110, reps: 4, sessionID: UUID(), segment: .warmUp),
            sample(exerciseID: exerciseID, dayOffset: 8, weight: 120, reps: 3, sessionID: UUID(), segment: .main)
        ]

        let summaries = calculator.weeklySummaries(from: samples)

        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries[0].totalSets, 2)
        XCTAssertEqual(summaries[0].totalReps, 9)
        XCTAssertEqual(try XCTUnwrap(summaries[0].totalLoad), 940, accuracy: 0.0001)
    }

    func test_exerciseVolumeTrend_defaultsToMainSegmentOnly() {
        let calculator = WeeklyVolumeCalculator(calendar: makeCalendar())
        let exerciseID = UUID()

        let samples = [
            sample(exerciseID: exerciseID, dayOffset: 0, weight: 100, reps: 5, sessionID: UUID(), segment: .warmUp),
            sample(exerciseID: exerciseID, dayOffset: 7, weight: 120, reps: 5, sessionID: UUID(), segment: .main)
        ]

        let trend = calculator.exerciseVolumeTrend(for: exerciseID, from: samples)

        XCTAssertEqual(trend.totalSets, 1)
        XCTAssertEqual(try XCTUnwrap(trend.totalLoad), 600, accuracy: 0.0001)
    }

    func test_exerciseVolumeTrend_returnsInsufficientData_whenNotEnoughBuckets() {
        let calculator = WeeklyVolumeCalculator(calendar: makeCalendar())
        let exerciseID = UUID()

        let trend = calculator.exerciseVolumeTrend(
            for: exerciseID,
            from: [sample(exerciseID: exerciseID, dayOffset: 0, weight: 100, reps: 5, sessionID: UUID(), segment: .main)]
        )

        XCTAssertEqual(trend.trendDirection, .insufficientData)
    }

    private func sample(
        exerciseID: UUID,
        dayOffset: Int,
        weight: Double?,
        reps: Int?,
        sessionID: UUID,
        segment: WorkoutExerciseSegment
    ) -> ExercisePerformanceSample {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: dayOffset, to: base)!

        return ExercisePerformanceSample(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessionID: sessionID,
            sessionStartedAt: date,
            performedAt: date,
            segment: segment,
            weight: weight,
            reps: reps,
            isCompleted: true
        )
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }
}
