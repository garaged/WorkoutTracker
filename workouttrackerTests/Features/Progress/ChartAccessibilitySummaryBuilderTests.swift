import XCTest
@testable import workouttracker

final class ChartAccessibilitySummaryBuilderTests: XCTestCase {
    func test_exerciseVolumeTrend_upSummary_mentionsTrendAndBestWeek() {
        let summary = ExerciseVolumeTrendSummary(
            exerciseID: UUID(),
            exerciseName: "Bench Press",
            weeklyBuckets: [
                ExerciseWeeklyVolumeBucket(weekStart: TestSupport.date(2026, 2, 23, calendar: TestSupport.utcCalendar), sets: 6, reps: 30, load: 1500),
                ExerciseWeeklyVolumeBucket(weekStart: TestSupport.date(2026, 3, 2, calendar: TestSupport.utcCalendar), sets: 8, reps: 40, load: 2200),
                ExerciseWeeklyVolumeBucket(weekStart: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar), sets: 9, reps: 45, load: 2500)
            ],
            totalSets: 23,
            totalReps: 115,
            totalLoad: 6200,
            trendDirection: .up,
            dataAvailability: .full
        )

        let built = ChartAccessibilitySummaryBuilder.exerciseVolumeTrend(
            summary,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertTrue(built.headline.contains("up"))
        XCTAssertEqual(built.detail, "Best week was Mar 9.")
        XCTAssertFalse(built.isLowData)
    }

    func test_exerciseVolumeTrend_limitedSummary_whenOnlyOneBucketExists() {
        let summary = ExerciseVolumeTrendSummary(
            exerciseID: UUID(),
            exerciseName: "Bench Press",
            weeklyBuckets: [
                ExerciseWeeklyVolumeBucket(weekStart: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar), sets: 4, reps: 20, load: 800)
            ],
            totalSets: 4,
            totalReps: 20,
            totalLoad: 800,
            trendDirection: .insufficientData,
            dataAvailability: .partial
        )

        let built = ChartAccessibilitySummaryBuilder.exerciseVolumeTrend(
            summary,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertTrue(built.headline.contains("Only 1 week"))
        XCTAssertTrue(built.isLowData)
    }

    func test_strengthCard_summary_marksLowDataWhenFallbackMessageExists() {
        let model = ProgressDashboardViewModel.StrengthCardModel(
            availability: .partial,
            headline: "Bench Press",
            summaryText: "Recent top set is available.",
            exercises: [],
            emptyMessage: "Need more sessions for a stronger trend."
        )

        let built = ChartAccessibilitySummaryBuilder.strengthCard(model)

        XCTAssertEqual(built.headline, "Bench Press")
        XCTAssertEqual(built.detail, "Need more sessions for a stronger trend.")
        XCTAssertTrue(built.isLowData)
    }
}
