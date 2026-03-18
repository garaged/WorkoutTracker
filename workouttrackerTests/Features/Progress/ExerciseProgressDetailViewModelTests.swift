import XCTest
@testable import workouttracker

@MainActor
final class ExerciseProgressDetailViewModelTests: XCTestCase {
    func test_load_mapsFullSummaryToContent() {
        let exerciseID = UUID()
        let summary = makeFullSummary(exerciseID: exerciseID)
        let viewModel = makeViewModel(summary: summary)

        viewModel.load(exerciseID: exerciseID)

        guard case .content(let content) = viewModel.state else {
            return XCTFail("Expected full-detail state.")
        }

        XCTAssertEqual(content.exerciseName, "Bench Press")
        XCTAssertEqual(content.personalRecords.count, 2)
        XCTAssertEqual(content.weeklyVolumeRows.count, 2)
        XCTAssertEqual(content.recentPerformanceRows.count, 2)
        XCTAssertEqual(content.estimatedOneRepMax?.title, "Estimated 1RM")
        XCTAssertEqual(content.latestTopSet?.title, "Latest top set")
        XCTAssertNil(content.lowDataMessage)
    }

    func test_load_mapsLowDataSummaryToLowDataState() {
        let exerciseID = UUID()
        let summary = makeLowDataSummary(exerciseID: exerciseID)
        let viewModel = makeViewModel(summary: summary)

        viewModel.load(exerciseID: exerciseID)

        guard case .lowData(let content) = viewModel.state else {
            return XCTFail("Expected low-data state.")
        }

        XCTAssertEqual(content.exerciseName, "Bench Press")
        XCTAssertTrue(content.personalRecords.isEmpty)
        XCTAssertNil(content.estimatedOneRepMax)
        XCTAssertNotNil(content.lowDataMessage)
    }

    func test_load_handlesMissingEstimatedOneRepMax() {
        let exerciseID = UUID()
        var summary = makeFullSummary(exerciseID: exerciseID)
        summary = ExerciseProgressDetailSummary(
            exerciseID: summary.exerciseID,
            exerciseName: summary.exerciseName,
            personalRecords: summary.personalRecords,
            weeklyVolumeTrend: summary.weeklyVolumeTrend,
            recentPerformanceSamples: summary.recentPerformanceSamples,
            estimatedOneRepMax: nil,
            latestTopSet: summary.latestTopSet,
            dataAvailability: summary.dataAvailability,
            hasLowData: summary.hasLowData
        )

        let viewModel = makeViewModel(summary: summary)
        viewModel.load(exerciseID: exerciseID)

        guard case .content(let content) = viewModel.state else {
            return XCTFail("Expected content state.")
        }

        XCTAssertNil(content.estimatedOneRepMax)
        XCTAssertNotNil(content.latestTopSet)
    }

    func test_load_formatsRecentPerformanceRows() throws {
        let exerciseID = UUID()
        let summary = makeFullSummary(exerciseID: exerciseID)
        let viewModel = makeViewModel(summary: summary)

        viewModel.load(exerciseID: exerciseID)

        guard case .content(let content) = viewModel.state else {
            return XCTFail("Expected content state.")
        }

        let first = try XCTUnwrap(content.recentPerformanceRows.first)
        XCTAssertEqual(first.valueText, "5 × 80")
        XCTAssertTrue(first.subtitleText.contains("Rest"))
    }

    private func makeViewModel(summary: ExerciseProgressDetailSummary) -> ExerciseProgressDetailViewModel {
        ExerciseProgressDetailViewModel(
            service: StubProgressAnalyticsService(detailSummary: summary),
            calendar: TestSupport.utcCalendar,
            locale: Locale(identifier: "en_US_POSIX"),
            now: { TestSupport.date(2026, 3, 16, calendar: TestSupport.utcCalendar) },
            windowWeeks: 12
        )
    }

    private func makeFullSummary(exerciseID: UUID) -> ExerciseProgressDetailSummary {
        let achievedAt = TestSupport.date(2026, 3, 10, calendar: TestSupport.utcCalendar)
        let earlier = TestSupport.date(2026, 3, 3, calendar: TestSupport.utcCalendar)

        return ExerciseProgressDetailSummary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            personalRecords: [
                PersonalRecordSummary(
                    kind: .heaviestWeight,
                    previousBest: 77.5,
                    currentBest: 80,
                    achievedAt: achievedAt,
                    sessionID: UUID(),
                    isNewRecord: true,
                    contextWeight: nil
                ),
                PersonalRecordSummary(
                    kind: .mostReps,
                    previousBest: 7,
                    currentBest: 8,
                    achievedAt: earlier,
                    sessionID: UUID(),
                    isNewRecord: false,
                    contextWeight: 70
                )
            ],
            weeklyVolumeTrend: ExerciseVolumeTrendSummary(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                weeklyBuckets: [
                    ExerciseWeeklyVolumeBucket(weekStart: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar), sets: 3, reps: 15, load: 1200),
                    ExerciseWeeklyVolumeBucket(weekStart: TestSupport.date(2026, 3, 2, calendar: TestSupport.utcCalendar), sets: 3, reps: 18, load: 1260)
                ],
                totalSets: 6,
                totalReps: 33,
                totalLoad: 2460,
                trendDirection: .up,
                dataAvailability: .full
            ),
            recentPerformanceSamples: [
                ExercisePerformanceSample(
                    id: UUID(),
                    exerciseID: exerciseID,
                    exerciseName: "Bench Press",
                    sessionID: UUID(),
                    sessionStartedAt: achievedAt,
                    performedAt: achievedAt,
                    segment: .main,
                    weight: 80,
                    reps: 5,
                    isCompleted: true,
                    plannedRestSeconds: 120,
                    actualRestSeconds: 140
                ),
                ExercisePerformanceSample(
                    id: UUID(),
                    exerciseID: exerciseID,
                    exerciseName: "Bench Press",
                    sessionID: UUID(),
                    sessionStartedAt: earlier,
                    performedAt: earlier,
                    segment: .main,
                    weight: 77.5,
                    reps: 6,
                    isCompleted: true,
                    plannedRestSeconds: 120,
                    actualRestSeconds: 120
                )
            ],
            estimatedOneRepMax: ExerciseProgressDetailSummary.EstimatedOneRepMaxSummary(
                value: 93.3,
                achievedAt: achievedAt,
                sessionID: UUID()
            ),
            latestTopSet: ExerciseProgressSummary.TopSetSnapshot(
                performedAt: achievedAt,
                sessionID: UUID(),
                weight: 80,
                reps: 5,
                estimatedOneRepMax: 93.3
            ),
            dataAvailability: .full,
            hasLowData: false
        )
    }

    private func makeLowDataSummary(exerciseID: UUID) -> ExerciseProgressDetailSummary {
        let achievedAt = TestSupport.date(2026, 3, 10, calendar: TestSupport.utcCalendar)

        return ExerciseProgressDetailSummary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            personalRecords: [],
            weeklyVolumeTrend: ExerciseVolumeTrendSummary(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                weeklyBuckets: [],
                totalSets: 1,
                totalReps: 8,
                totalLoad: 440,
                trendDirection: .insufficientData,
                dataAvailability: .insufficient
            ),
            recentPerformanceSamples: [
                ExercisePerformanceSample(
                    id: UUID(),
                    exerciseID: exerciseID,
                    exerciseName: "Bench Press",
                    sessionID: UUID(),
                    sessionStartedAt: achievedAt,
                    performedAt: achievedAt,
                    segment: .main,
                    weight: 55,
                    reps: 8,
                    isCompleted: true,
                    plannedRestSeconds: nil,
                    actualRestSeconds: nil
                )
            ],
            estimatedOneRepMax: nil,
            latestTopSet: nil,
            dataAvailability: .partial,
            hasLowData: true
        )
    }
}

@MainActor
private struct StubProgressAnalyticsService: ProgressAnalyticsServicing {
    var detailSummary: ExerciseProgressDetailSummary

    func dashboardSummary(for window: DateInterval) throws -> ProgressDashboardSummary {
        ProgressDashboardSummary(
            featuredExercises: [],
            weeklySummary: nil,
            consistency: ConsistencySummary(
                window: window,
                activeWeeks: 0,
                totalWeeks: 12,
                averageWorkoutsPerWeek: 0,
                completionRate: nil,
                dataAvailability: .insufficient
            ),
            efficiency: nil,
            dataAvailability: .insufficient,
            isEmpty: true,
            hasLowData: true
        )
    }

    func exerciseDetailSummary(for exerciseID: UUID, window: DateInterval?) throws -> ExerciseProgressDetailSummary {
        detailSummary
    }
}
