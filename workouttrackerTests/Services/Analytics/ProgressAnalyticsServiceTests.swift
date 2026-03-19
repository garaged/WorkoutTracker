import XCTest
@testable import workouttracker

@MainActor
final class ProgressAnalyticsServiceTests: XCTestCase {
    func test_dashboardSummary_withFullData_assemblesAllSections() throws {
        let calendar = TestSupport.utcCalendar
        let benchID = UUID()
        let squatID = UUID()
        let base = TestSupport.date(2026, 3, 2, 0, 0, calendar: calendar)
        let window = DateInterval(start: base, end: calendar.date(byAdding: .day, value: 13, to: base)!)

        let sessions = [
            SessionAnalyticsSample(
                id: UUID(),
                startedAt: calendar.date(byAdding: .day, value: 0, to: base)!,
                endedAt: calendar.date(byAdding: .minute, value: 45, to: base)!,
                wasCompleted: true,
                completedExerciseCount: 2,
                durationSeconds: 2_700,
                segmentsPresent: [.main]
            ),
            SessionAnalyticsSample(
                id: UUID(),
                startedAt: calendar.date(byAdding: .day, value: 7, to: base)!,
                endedAt: calendar.date(byAdding: .minute, value: 50, to: base)!,
                wasCompleted: true,
                completedExerciseCount: 2,
                durationSeconds: 3_000,
                segmentsPresent: [.main]
            )
        ]

        let samples = [
            sample(exerciseID: benchID, name: "Bench Press", sessionID: sessions[0].id, date: sessions[0].startedAt, weight: 100, reps: 5, plannedRest: 120, actualRest: 150),
            sample(exerciseID: benchID, name: "Bench Press", sessionID: sessions[1].id, date: sessions[1].startedAt, weight: 105, reps: 5, plannedRest: 120, actualRest: 135),
            sample(exerciseID: squatID, name: "Squat", sessionID: sessions[0].id, date: sessions[0].startedAt.addingTimeInterval(300), weight: 140, reps: 5, plannedRest: 180, actualRest: 210),
            sample(exerciseID: squatID, name: "Squat", sessionID: sessions[1].id, date: sessions[1].startedAt.addingTimeInterval(300), weight: 145, reps: 5, plannedRest: 180, actualRest: 195)
        ]

        let dataSource = StubProgressAnalyticsDataSource(
            performanceSamples: samples,
            completedSessions: sessions
        )
        let service = makeService(dataSource: dataSource, calendar: calendar)

        let summary = try service.dashboardSummary(for: window)

        XCTAssertEqual(summary.dataAvailability, .full)
        XCTAssertFalse(summary.isEmpty)
        XCTAssertFalse(summary.hasLowData)
        XCTAssertEqual(summary.featuredExercises.map(\.exerciseName), ["Squat", "Bench Press"])
        XCTAssertEqual(summary.weeklySummary?.workoutsCompleted, 1)
        XCTAssertEqual(summary.consistency.activeWeeks, 2)
        XCTAssertEqual(summary.efficiency?.availability, .full)
        XCTAssertEqual(summary.efficiency?.highestAverageRestOverrunExercises.count, 2)
        XCTAssertEqual(dataSource.lastDashboardWindow, window)
    }

    func test_dashboardSummary_withLowData_stillReturnsUsableOutput() throws {
        let calendar = TestSupport.utcCalendar
        let exerciseID = UUID()
        let base = TestSupport.date(2026, 3, 9, 0, 0, calendar: calendar)
        let window = DateInterval(start: base, end: calendar.date(byAdding: .day, value: 6, to: base)!)

        let sessions = [
            SessionAnalyticsSample(
                id: UUID(),
                startedAt: base,
                endedAt: nil,
                wasCompleted: true,
                completedExerciseCount: 1,
                durationSeconds: nil,
                segmentsPresent: [.main]
            )
        ]

        let samples = [
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Farmer Carry",
                sessionID: sessions[0].id,
                sessionStartedAt: base,
                performedAt: base,
                segment: .main,
                weight: 40,
                reps: nil,
                isCompleted: true,
                plannedRestSeconds: nil,
                actualRestSeconds: nil
            )
        ]

        let service = makeService(
            dataSource: StubProgressAnalyticsDataSource(performanceSamples: samples, completedSessions: sessions),
            calendar: calendar
        )

        let summary = try service.dashboardSummary(for: window)

        XCTAssertEqual(summary.dataAvailability, .partial)
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.hasLowData)
        XCTAssertEqual(summary.featuredExercises.count, 1)
        XCTAssertEqual(summary.featuredExercises[0].dataAvailability, .partial)
        XCTAssertEqual(summary.weeklySummary?.dataAvailability, .partial)
        XCTAssertNil(summary.efficiency)
    }

    func test_exerciseDetailSummary_returnsTrend_recentSamples_andEstimatedOneRepMax() throws {
        let calendar = TestSupport.utcCalendar
        let exerciseID = UUID()
        let base = TestSupport.date(2026, 3, 2, 0, 0, calendar: calendar)

        let week0 = base.addingTimeInterval(7 * 3_600)
        let week1 = calendar.date(byAdding: .day, value: 7, to: week0)!

        let samples = [
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: UUID(),
                sessionStartedAt: week0,
                performedAt: week0,
                segment: .warmUp,
                weight: 60,
                reps: 10,
                isCompleted: true,
                plannedRestSeconds: 60,
                actualRestSeconds: 70
            ),
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: UUID(),
                sessionStartedAt: week0,
                performedAt: week0.addingTimeInterval(120),
                segment: .main,
                weight: 100,
                reps: 5,
                isCompleted: true,
                plannedRestSeconds: 120,
                actualRestSeconds: 140
            ),
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: UUID(),
                sessionStartedAt: week1,
                performedAt: week1,
                segment: .main,
                weight: 105,
                reps: 5,
                isCompleted: true,
                plannedRestSeconds: 120,
                actualRestSeconds: 150
            )
        ]

        let dataSource = StubProgressAnalyticsDataSource(performanceSamples: samples, completedSessions: [])
        let service = makeService(dataSource: dataSource, calendar: calendar)

        let detail = try service.exerciseDetailSummary(for: exerciseID, window: nil)

        XCTAssertEqual(detail.exerciseName, "Bench Press")
        XCTAssertEqual(detail.personalRecords.map(\.kind), [.heaviestWeight, .mostReps, .highestEstimatedOneRepMax, .highestSessionVolume])
        XCTAssertEqual(detail.weeklyVolumeTrend.weeklyBuckets.count, 2)
        XCTAssertEqual(detail.recentPerformanceSamples.count, 2)
        XCTAssertTrue(detail.recentPerformanceSamples.allSatisfy { $0.segment == .main })
        XCTAssertEqual(try XCTUnwrap(detail.estimatedOneRepMax).value, 122.5, accuracy: 0.0001)
        XCTAssertEqual(detail.dataAvailability, .full)
        XCTAssertEqual(dataSource.lastExerciseID, exerciseID)
        XCTAssertNil(dataSource.lastExerciseWindow)
    }

    func test_dashboardSummary_missingEfficiencyDataStillProducesValidOutput() throws {
        let calendar = TestSupport.utcCalendar
        let exerciseID = UUID()
        let base = TestSupport.date(2026, 3, 2, 0, 0, calendar: calendar)
        let window = DateInterval(start: base, end: calendar.date(byAdding: .day, value: 13, to: base)!)

        let sessions = [
            SessionAnalyticsSample(
                id: UUID(),
                startedAt: base,
                endedAt: nil,
                wasCompleted: true,
                completedExerciseCount: 1,
                durationSeconds: nil,
                segmentsPresent: [.main]
            ),
            SessionAnalyticsSample(
                id: UUID(),
                startedAt: calendar.date(byAdding: .day, value: 7, to: base)!,
                endedAt: nil,
                wasCompleted: true,
                completedExerciseCount: 1,
                durationSeconds: nil,
                segmentsPresent: [.main]
            )
        ]

        let samples = [
            sample(exerciseID: exerciseID, name: "Row", sessionID: sessions[0].id, date: sessions[0].startedAt, weight: 90, reps: 8),
            sample(exerciseID: exerciseID, name: "Row", sessionID: sessions[1].id, date: sessions[1].startedAt, weight: 95, reps: 8)
        ]

        let service = makeService(
            dataSource: StubProgressAnalyticsDataSource(performanceSamples: samples, completedSessions: sessions),
            calendar: calendar
        )

        let summary = try service.dashboardSummary(for: window)

        XCTAssertNil(summary.efficiency)
        XCTAssertEqual(summary.dataAvailability, .partial)
        XCTAssertEqual(summary.featuredExercises.count, 1)
        XCTAssertNotNil(summary.weeklySummary)
        XCTAssertEqual(summary.consistency.dataAvailability, .full)
    }

    private func makeService(
        dataSource: StubProgressAnalyticsDataSource,
        calendar: Calendar
    ) -> ProgressAnalyticsService {
        ProgressAnalyticsService(
            dataSource: dataSource,
            personalRecordCalculator: PersonalRecordCalculator(),
            weeklyVolumeCalculator: WeeklyVolumeCalculator(calendar: calendar),
            consistencyCalculator: ConsistencyCalculator(calendar: calendar),
            sessionEfficiencyCalculator: SessionEfficiencyCalculator(),
            maxFeaturedExercises: 5,
            recentSampleLimit: 8
        )
    }

    private func sample(
        exerciseID: UUID,
        name: String,
        sessionID: UUID,
        date: Date,
        weight: Double,
        reps: Int,
        plannedRest: Int? = nil,
        actualRest: Int? = nil
    ) -> ExercisePerformanceSample {
        ExercisePerformanceSample(
            exerciseID: exerciseID,
            exerciseName: name,
            sessionID: sessionID,
            sessionStartedAt: date,
            performedAt: date,
            segment: .main,
            weight: weight,
            reps: reps,
            isCompleted: true,
            plannedRestSeconds: plannedRest,
            actualRestSeconds: actualRest
        )
    }
}

@MainActor
private final class StubProgressAnalyticsDataSource: ProgressAnalyticsDataSource {
    let performanceSamples: [ExercisePerformanceSample]
    let completedSessions: [SessionAnalyticsSample]

    private(set) var lastDashboardWindow: DateInterval?
    private(set) var lastExerciseID: UUID?
    private(set) var lastExerciseWindow: DateInterval?

    init(
        performanceSamples: [ExercisePerformanceSample],
        completedSessions: [SessionAnalyticsSample]
    ) {
        self.performanceSamples = performanceSamples
        self.completedSessions = completedSessions
    }

    func loadPerformanceSamples(in window: DateInterval?) throws -> [ExercisePerformanceSample] {
        lastDashboardWindow = window
        return filter(performanceSamples, in: window)
    }

    func loadPerformanceSamples(for exerciseID: UUID, in window: DateInterval?) throws -> [ExercisePerformanceSample] {
        lastExerciseID = exerciseID
        lastExerciseWindow = window
        return filter(performanceSamples.filter { $0.exerciseID == exerciseID }, in: window)
    }

    func loadSessionAnalyticsSamples(in window: DateInterval?) throws -> [SessionAnalyticsSample] {
        filter(completedSessions, in: window)
    }

    private func filter(_ samples: [ExercisePerformanceSample], in window: DateInterval?) -> [ExercisePerformanceSample] {
        guard let window else { return samples }
        return samples.filter { window.contains($0.sessionStartedAt) }
    }

    private func filter(_ sessions: [SessionAnalyticsSample], in window: DateInterval?) -> [SessionAnalyticsSample] {
        guard let window else { return sessions }
        return sessions.filter { window.contains($0.startedAt) }
    }
}
