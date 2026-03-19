import XCTest
@testable import workouttracker

@MainActor
final class ProgressDashboardViewModelTests: XCTestCase {
    func test_load_mapsEmptySummaryToNoWorkoutsState() {
        let service = StubProgressAnalyticsService(
            dashboard: .empty,
            detail: ProgressDashboardViewModelTests.anyDetailSummary()
        )
        let viewModel = makeViewModel(service: service)

        viewModel.load()

        XCTAssertEqual(viewModel.state, .emptyNoWorkouts)
    }

    func test_load_mapsLowDataSummary_toPerCardFallbackState() {
        let service = StubProgressAnalyticsService(
            dashboard: .lowData,
            detail: ProgressDashboardViewModelTests.anyDetailSummary()
        )
        let viewModel = makeViewModel(service: service)

        viewModel.load()

        guard case .lowData(let content) = viewModel.state else {
            return XCTFail("Expected low-data content state")
        }

        XCTAssertEqual(content.strength.availability, .partial)
        XCTAssertEqual(content.strength.exercises.map(\.exerciseName), ["Bench Press"])
        XCTAssertEqual(content.volume.availability, .insufficient)
        XCTAssertEqual(content.volume.emptyMessage, "Complete more workouts in this window to build weekly sets, reps, and load totals.")
        XCTAssertEqual(content.consistency.availability, .partial)
        XCTAssertEqual(content.recovery.availability, .insufficient)
        XCTAssertEqual(service.lastWindow?.start, TestSupport.date(2025, 12, 22, calendar: TestSupport.utcCalendar))
        XCTAssertEqual(service.lastWindow?.end, TestSupport.date(2026, 3, 16, calendar: TestSupport.utcCalendar))
    }

    func test_load_mapsFullSummaryToCardModels() {
        let service = StubProgressAnalyticsService(
            dashboard: .full,
            detail: ProgressDashboardViewModelTests.anyDetailSummary()
        )
        let viewModel = makeViewModel(service: service)

        viewModel.load()

        guard case .content(let content) = viewModel.state else {
            return XCTFail("Expected content state")
        }

        XCTAssertEqual(content.strength.availability, .full)
        XCTAssertEqual(content.strength.exercises.count, 2)
        XCTAssertEqual(content.volume.availability, .full)
        XCTAssertEqual(content.volume.stats.map(\.label), ["Workouts", "Sets", "Reps", "Exercises"])
        XCTAssertEqual(content.consistency.availability, .full)
        XCTAssertEqual(content.consistency.completionText, "82% completion")
        XCTAssertEqual(content.recovery.availability, .full)
        XCTAssertEqual(content.windowTitle, "Dec 22 – Mar 15")
    }

    func test_load_strengthCard_prefersPRHeadline_whenRecentRecordsExist() {
        let service = StubProgressAnalyticsService(
            dashboard: .full,
            detail: ProgressDashboardViewModelTests.anyDetailSummary()
        )
        let viewModel = makeViewModel(service: service)

        viewModel.load()

        guard case .content(let content) = viewModel.state else {
            return XCTFail("Expected content state")
        }

        XCTAssertEqual(content.strength.headline, "1 recent PR")
        XCTAssertEqual(content.strength.exercises.first?.badgeText, "PR")
    }

    func test_load_recoveryCard_usesPartialFallback_whenRestComparisonIsUnavailable() {
        let service = StubProgressAnalyticsService(
            dashboard: .efficiencyPartialNoOverrun,
            detail: ProgressDashboardViewModelTests.anyDetailSummary()
        )
        let viewModel = makeViewModel(service: service)

        viewModel.load()

        guard case .lowData(let content) = viewModel.state else {
            return XCTFail("Expected low-data content state")
        }

        XCTAssertEqual(content.recovery.availability, .partial)
        XCTAssertEqual(content.recovery.emptyMessage, "Efficiency has partial timing data, but rest comparison still needs more logged sessions.")
        XCTAssertEqual(content.recovery.actualRestText, "2m 18s")
    }

    func test_load_keepsConsistencyCard_butMarksItUnavailable_whenDataIsThin() {
        let service = StubProgressAnalyticsService(
            dashboard: .consistencyLowData,
            detail: ProgressDashboardViewModelTests.anyDetailSummary()
        )
        let viewModel = makeViewModel(service: service)

        viewModel.load()

        guard case .lowData(let content) = viewModel.state else {
            return XCTFail("Expected low-data content state")
        }

        XCTAssertEqual(content.consistency.availability, .insufficient)
        XCTAssertNotNil(content.consistency.emptyMessage)
        XCTAssertEqual(content.recovery.availability, .partial)
    }

    func test_openExerciseDetail_tracksSelectedExerciseID() {
        let service = StubProgressAnalyticsService(
            dashboard: .full,
            detail: ProgressDashboardViewModelTests.anyDetailSummary()
        )
        let viewModel = makeViewModel(service: service)
        let id = UUID()

        viewModel.openExerciseDetail(exerciseID: id)

        XCTAssertEqual(viewModel.selectedExerciseID, id)
    }

    private func makeViewModel(service: StubProgressAnalyticsService) -> ProgressDashboardViewModel {
        ProgressDashboardViewModel(
            service: service,
            calendar: TestSupport.utcCalendar,
            locale: Locale(identifier: "en_US_POSIX"),
            now: { TestSupport.date(2026, 3, 16, calendar: TestSupport.utcCalendar) },
            windowWeeks: 12
        )
    }

    private static func anyDetailSummary() -> ExerciseProgressDetailSummary {
        ExerciseProgressDetailSummary(
            exerciseID: UUID(),
            exerciseName: "Bench Press",
            personalRecords: [],
            weeklyVolumeTrend: ExerciseVolumeTrendSummary(
                exerciseID: UUID(),
                exerciseName: "Bench Press",
                weeklyBuckets: [],
                totalSets: 0,
                totalReps: 0,
                totalLoad: nil,
                trendDirection: .insufficientData,
                dataAvailability: .insufficient
            ),
            recentPerformanceSamples: [],
            estimatedOneRepMax: nil,
            latestTopSet: nil,
            dataAvailability: .insufficient,
            hasLowData: true
        )
    }
}

@MainActor
private final class StubProgressAnalyticsService: ProgressAnalyticsServicing {
    let dashboard: ProgressDashboardSummary
    let detail: ExerciseProgressDetailSummary
    private(set) var lastWindow: DateInterval?

    init(dashboard: ProgressDashboardSummary, detail: ExerciseProgressDetailSummary) {
        self.dashboard = dashboard
        self.detail = detail
    }

    func dashboardSummary(for window: DateInterval) throws -> ProgressDashboardSummary {
        lastWindow = window
        return dashboard
    }

    func exerciseDetailSummary(for exerciseID: UUID, window: DateInterval?) throws -> ExerciseProgressDetailSummary {
        detail
    }
}

private extension ProgressDashboardSummary {
    static var empty: Self {
        ProgressDashboardSummary(
            featuredExercises: [],
            weeklySummary: nil,
            consistency: ConsistencySummary(
                window: DateInterval(start: TestSupport.date(2026, 1, 1, calendar: TestSupport.utcCalendar), end: TestSupport.date(2026, 3, 16, calendar: TestSupport.utcCalendar)),
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

    static var lowData: Self {
        ProgressDashboardSummary(
            featuredExercises: [benchPartial()],
            weeklySummary: nil,
            consistency: ConsistencySummary(
                window: sampleWindow(),
                activeWeeks: 1,
                totalWeeks: 12,
                averageWorkoutsPerWeek: 0.5,
                completionRate: nil,
                dataAvailability: .partial
            ),
            efficiency: nil,
            dataAvailability: .partial,
            isEmpty: false,
            hasLowData: true
        )
    }

    static var consistencyLowData: Self {
        ProgressDashboardSummary(
            featuredExercises: [benchFull()],
            weeklySummary: WeeklyTrainingSummary(
                weekStart: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                workoutsCompleted: 2,
                totalSets: 10,
                totalReps: 50,
                totalLoad: 3_500,
                distinctExerciseCount: 2,
                totalDurationSeconds: 3_200,
                dataAvailability: .full
            ),
            consistency: ConsistencySummary(
                window: sampleWindow(),
                activeWeeks: 1,
                totalWeeks: 12,
                averageWorkoutsPerWeek: 0.2,
                completionRate: nil,
                dataAvailability: .insufficient
            ),
            efficiency: SessionEfficiencySummary(
                averageSessionDurationSeconds: 2_900,
                averagePlannedRestSeconds: 120,
                averageActualRestSeconds: 138,
                averageRestOverrunSeconds: 18,
                highestAverageRestOverrunExercises: [],
                availability: .partial
            ),
            dataAvailability: .partial,
            isEmpty: false,
            hasLowData: true
        )
    }

    static var efficiencyPartialNoOverrun: Self {
        ProgressDashboardSummary(
            featuredExercises: [benchFull()],
            weeklySummary: WeeklyTrainingSummary(
                weekStart: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                workoutsCompleted: 2,
                totalSets: 10,
                totalReps: 50,
                totalLoad: 3_500,
                distinctExerciseCount: 2,
                totalDurationSeconds: 3_200,
                dataAvailability: .full
            ),
            consistency: ConsistencySummary(
                window: sampleWindow(),
                activeWeeks: 4,
                totalWeeks: 12,
                averageWorkoutsPerWeek: 1.2,
                completionRate: 0.7,
                dataAvailability: .partial
            ),
            efficiency: SessionEfficiencySummary(
                averageSessionDurationSeconds: 2_900,
                averagePlannedRestSeconds: 120,
                averageActualRestSeconds: 138,
                averageRestOverrunSeconds: nil,
                highestAverageRestOverrunExercises: [],
                availability: .partial
            ),
            dataAvailability: .partial,
            isEmpty: false,
            hasLowData: true
        )
    }

    static var full: Self {
        ProgressDashboardSummary(
            featuredExercises: [benchFull(), squatFull()],
            weeklySummary: WeeklyTrainingSummary(
                weekStart: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                workoutsCompleted: 3,
                totalSets: 14,
                totalReps: 66,
                totalLoad: 6_240,
                distinctExerciseCount: 4,
                totalDurationSeconds: 5_400,
                dataAvailability: .full
            ),
            consistency: ConsistencySummary(
                window: sampleWindow(),
                activeWeeks: 8,
                totalWeeks: 12,
                averageWorkoutsPerWeek: 2.2,
                completionRate: 0.82,
                dataAvailability: .full
            ),
            efficiency: SessionEfficiencySummary(
                averageSessionDurationSeconds: 3_450,
                averagePlannedRestSeconds: 135,
                averageActualRestSeconds: 149,
                averageRestOverrunSeconds: 14,
                highestAverageRestOverrunExercises: [],
                availability: .full
            ),
            dataAvailability: .full,
            isEmpty: false,
            hasLowData: false
        )
    }

    private static func sampleWindow() -> DateInterval {
        DateInterval(
            start: TestSupport.date(2025, 12, 22, calendar: TestSupport.utcCalendar),
            end: TestSupport.date(2026, 3, 16, calendar: TestSupport.utcCalendar)
        )
    }

    private static func benchPartial() -> ExerciseProgressSummary {
        ExerciseProgressSummary(
            exerciseID: UUID(),
            exerciseName: "Bench Press",
            bestWeight: .init(
                value: 100,
                achievedAt: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                sessionID: UUID()
            ),
            bestReps: nil,
            bestSetVolume: nil,
            bestSessionVolume: nil,
            bestEstimatedOneRepMax: nil,
            latestTopSet: .init(
                performedAt: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                sessionID: UUID(),
                weight: 100,
                reps: 5,
                estimatedOneRepMax: nil
            ),
            latestPerformedAt: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
            personalRecords: [],
            dataAvailability: .partial
        )
    }

    private static func benchFull() -> ExerciseProgressSummary {
        ExerciseProgressSummary(
            exerciseID: UUID(),
            exerciseName: "Bench Press",
            bestWeight: .init(
                value: 107.5,
                achievedAt: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                sessionID: UUID()
            ),
            bestReps: .init(
                value: 8,
                achievedAt: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                sessionID: UUID(),
                contextWeight: 100
            ),
            bestSetVolume: nil,
            bestSessionVolume: nil,
            bestEstimatedOneRepMax: nil,
            latestTopSet: .init(
                performedAt: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                sessionID: UUID(),
                weight: 107.5,
                reps: 5,
                estimatedOneRepMax: nil
            ),
            latestPerformedAt: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
            personalRecords: [
                PersonalRecordSummary(
                    kind: .heaviestWeight,
                    previousBest: 105,
                    currentBest: 107.5,
                    achievedAt: TestSupport.date(2026, 3, 9, calendar: TestSupport.utcCalendar),
                    sessionID: UUID(),
                    isNewRecord: true,
                    contextWeight: nil
                )
            ],
            dataAvailability: .full
        )
    }

    private static func squatFull() -> ExerciseProgressSummary {
        ExerciseProgressSummary(
            exerciseID: UUID(),
            exerciseName: "Squat",
            bestWeight: .init(
                value: 150,
                achievedAt: TestSupport.date(2026, 3, 12, calendar: TestSupport.utcCalendar),
                sessionID: UUID()
            ),
            bestReps: nil,
            bestSetVolume: nil,
            bestSessionVolume: nil,
            bestEstimatedOneRepMax: .init(
                value: 175,
                achievedAt: TestSupport.date(2026, 3, 12, calendar: TestSupport.utcCalendar),
                sessionID: UUID()
            ),
            latestTopSet: .init(
                performedAt: TestSupport.date(2026, 3, 12, calendar: TestSupport.utcCalendar),
                sessionID: UUID(),
                weight: 150,
                reps: 5,
                estimatedOneRepMax: 175
            ),
            latestPerformedAt: TestSupport.date(2026, 3, 12, calendar: TestSupport.utcCalendar),
            personalRecords: [],
            dataAvailability: .full
        )
    }
}
