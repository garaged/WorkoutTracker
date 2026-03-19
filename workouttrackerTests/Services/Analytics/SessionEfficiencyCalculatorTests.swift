import XCTest
@testable import workouttracker

final class SessionEfficiencyCalculatorTests: XCTestCase {
    func test_summary_computesAverageRestAndOverrun() {
        let calculator = SessionEfficiencyCalculator()
        let exerciseID = UUID()
        let sessionID = UUID()
        let startedAt = TestSupport.date(2026, 3, 1, 7, 0)

        let samples = [
            sample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: sessionID,
                sessionStartedAt: startedAt,
                performedAt: startedAt,
                plannedRestSeconds: 120,
                actualRestSeconds: nil
            ),
            sample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: sessionID,
                sessionStartedAt: startedAt,
                performedAt: startedAt.addingTimeInterval(180),
                plannedRestSeconds: 120,
                actualRestSeconds: 150
            ),
            sample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: sessionID,
                sessionStartedAt: startedAt,
                performedAt: startedAt.addingTimeInterval(360),
                plannedRestSeconds: 120,
                actualRestSeconds: 180
            )
        ]

        let sessions = [
            SessionAnalyticsSample(
                id: sessionID,
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(2_400),
                wasCompleted: true,
                completedExerciseCount: 1,
                durationSeconds: 2_400,
                segmentsPresent: [.main]
            )
        ]

        let summary = calculator.summary(from: samples, sessions: sessions)

        XCTAssertEqual(summary.availability, .full)
        XCTAssertEqual(try XCTUnwrap(summary.averageSessionDurationSeconds), 2_400, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(summary.averagePlannedRestSeconds), 120, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(summary.averageActualRestSeconds), 165, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(summary.averageRestOverrunSeconds), 45, accuracy: 0.0001)
        XCTAssertEqual(summary.highestAverageRestOverrunExercises.count, 1)
        XCTAssertEqual(summary.highestAverageRestOverrunExercises[0].exerciseName, "Bench Press")
        XCTAssertEqual(summary.highestAverageRestOverrunExercises[0].sampleCount, 2)
    }

    func test_summary_returnsPartialWhenOnlyDurationDataIsReliable() {
        let calculator = SessionEfficiencyCalculator()
        let startedAt = TestSupport.date(2026, 3, 2, 7, 0)

        let sessions = [
            SessionAnalyticsSample(
                id: UUID(),
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(1_800),
                wasCompleted: true,
                completedExerciseCount: 3,
                durationSeconds: 1_800,
                segmentsPresent: [.main]
            )
        ]

        let summary = calculator.summary(from: [], sessions: sessions)

        XCTAssertEqual(summary.availability, .partial)
        XCTAssertEqual(try XCTUnwrap(summary.averageSessionDurationSeconds), 1_800, accuracy: 0.0001)
        XCTAssertNil(summary.averagePlannedRestSeconds)
        XCTAssertNil(summary.averageActualRestSeconds)
        XCTAssertNil(summary.averageRestOverrunSeconds)
        XCTAssertTrue(summary.highestAverageRestOverrunExercises.isEmpty)
    }

    func test_summary_returnsInsufficientWhenNoEfficiencyDataExists() {
        let calculator = SessionEfficiencyCalculator()

        let sessions = [
            SessionAnalyticsSample(
                id: UUID(),
                startedAt: TestSupport.date(2026, 3, 3, 7, 0),
                endedAt: nil,
                wasCompleted: true,
                completedExerciseCount: 2,
                durationSeconds: nil,
                segmentsPresent: [.main]
            )
        ]

        let summary = calculator.summary(from: [], sessions: sessions)

        XCTAssertEqual(summary.availability, .insufficient)
        XCTAssertNil(summary.averageSessionDurationSeconds)
        XCTAssertNil(summary.averagePlannedRestSeconds)
        XCTAssertNil(summary.averageActualRestSeconds)
        XCTAssertNil(summary.averageRestOverrunSeconds)
        XCTAssertTrue(summary.highestAverageRestOverrunExercises.isEmpty)
    }

    func test_summary_ignoresWarmUpAndCoolDownByDefault() {
        let calculator = SessionEfficiencyCalculator()
        let exerciseID = UUID()
        let sessionID = UUID()
        let startedAt = TestSupport.date(2026, 3, 4, 7, 0)

        let samples = [
            sample(
                exerciseID: exerciseID,
                exerciseName: "Squat",
                sessionID: sessionID,
                sessionStartedAt: startedAt,
                performedAt: startedAt,
                segment: .warmUp,
                plannedRestSeconds: 60,
                actualRestSeconds: 180
            ),
            sample(
                exerciseID: exerciseID,
                exerciseName: "Squat",
                sessionID: sessionID,
                sessionStartedAt: startedAt,
                performedAt: startedAt.addingTimeInterval(180),
                segment: .main,
                plannedRestSeconds: 120,
                actualRestSeconds: 135
            ),
            sample(
                exerciseID: exerciseID,
                exerciseName: "Squat",
                sessionID: sessionID,
                sessionStartedAt: startedAt,
                performedAt: startedAt.addingTimeInterval(360),
                segment: .main,
                plannedRestSeconds: 120,
                actualRestSeconds: 150
            )
        ]

        let summary = calculator.summary(from: samples, sessions: [])

        XCTAssertEqual(summary.availability, .full)
        XCTAssertEqual(try XCTUnwrap(summary.averagePlannedRestSeconds), 120, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(summary.averageActualRestSeconds), 142.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(summary.averageRestOverrunSeconds), 22.5, accuracy: 0.0001)
    }

    private func sample(
        exerciseID: UUID,
        exerciseName: String,
        sessionID: UUID,
        sessionStartedAt: Date,
        performedAt: Date,
        segment: WorkoutExerciseSegment = .main,
        plannedRestSeconds: Int?,
        actualRestSeconds: Int?
    ) -> ExercisePerformanceSample {
        ExercisePerformanceSample(
            exerciseID: exerciseID,
            exerciseName: exerciseName,
            sessionID: sessionID,
            sessionStartedAt: sessionStartedAt,
            performedAt: performedAt,
            segment: segment,
            weight: 100,
            reps: 5,
            isCompleted: true,
            plannedRestSeconds: plannedRestSeconds,
            actualRestSeconds: actualRestSeconds
        )
    }
}
