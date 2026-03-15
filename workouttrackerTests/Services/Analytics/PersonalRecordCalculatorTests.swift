import XCTest
@testable import workouttracker

final class PersonalRecordCalculatorTests: XCTestCase {

    private let calculator = PersonalRecordCalculator()

    func test_summarizeExerciseProgress_detectsPRsFromMainSegmentSamples() {
        let exerciseID = UUID()
        let session0 = UUID()
        let session1 = UUID()
        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        let day1 = day0.addingTimeInterval(86_400)

        let samples = [
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: session0,
                sessionStartedAt: day0,
                performedAt: day0,
                segment: .main,
                weight: 100,
                reps: 5
            ),
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: session1,
                sessionStartedAt: day1,
                performedAt: day1,
                segment: .main,
                weight: 110,
                reps: 4
            )
        ]

        let summary = calculator.summarizeExerciseProgress(
            for: exerciseID,
            exerciseName: "Bench Press",
            samples: samples
        )

        XCTAssertEqual(try XCTUnwrap(summary.bestWeight).value, 110, accuracy: 0.000_1)
        XCTAssertEqual(summary.bestReps?.value, 5)
        XCTAssertEqual(try XCTUnwrap(summary.bestSessionVolume).value, 500, accuracy: 0.000_1)
        XCTAssertEqual(summary.dataAvailability, .full)
        XCTAssertEqual(summary.personalRecords.map(\.kind), [.heaviestWeight, .mostReps, .highestEstimatedOneRepMax, .highestSessionVolume])
        XCTAssertTrue(summary.personalRecords.contains(where: { $0.kind == .heaviestWeight && $0.isNewRecord }))
    }

    func test_summarizeExerciseProgress_ignoresWarmUpAndCoolDownByDefault() {
        let exerciseID = UUID()
        let session0 = UUID()
        let day0 = Date(timeIntervalSince1970: 1_700_000_000)

        let samples = [
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Squat",
                sessionID: session0,
                sessionStartedAt: day0,
                performedAt: day0,
                segment: .warmUp,
                weight: 225,
                reps: 10
            ),
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Squat",
                sessionID: session0,
                sessionStartedAt: day0,
                performedAt: day0.addingTimeInterval(120),
                segment: .main,
                weight: 185,
                reps: 5
            )
        ]

        let summary = calculator.summarizeExerciseProgress(
            for: exerciseID,
            exerciseName: "Squat",
            samples: samples
        )

        XCTAssertEqual(try XCTUnwrap(summary.bestWeight).value, 185, accuracy: 0.000_1)
        XCTAssertEqual(summary.bestReps?.value, 5)
    }

    func test_summarizeExerciseProgress_canIncludeNonMainSegmentsWhenRequested() {
        let exerciseID = UUID()
        let session0 = UUID()
        let day0 = Date(timeIntervalSince1970: 1_700_000_000)

        let samples = [
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Squat",
                sessionID: session0,
                sessionStartedAt: day0,
                performedAt: day0,
                segment: .warmUp,
                weight: 225,
                reps: 10
            ),
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Squat",
                sessionID: session0,
                sessionStartedAt: day0,
                performedAt: day0.addingTimeInterval(120),
                segment: .main,
                weight: 185,
                reps: 5
            )
        ]

        let summary = calculator.summarizeExerciseProgress(
            for: exerciseID,
            exerciseName: "Squat",
            samples: samples,
            includeNonMainSegments: true
        )

        XCTAssertEqual(try XCTUnwrap(summary.bestWeight).value, 225, accuracy: 0.000_1)
        XCTAssertEqual(summary.bestReps?.value, 10)
    }

    func test_summarizeExerciseProgress_ignoresIncompleteSamples() {
        let exerciseID = UUID()
        let session0 = UUID()
        let day0 = Date(timeIntervalSince1970: 1_700_000_000)

        let samples = [
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Deadlift",
                sessionID: session0,
                sessionStartedAt: day0,
                performedAt: day0,
                segment: .main,
                weight: 315,
                reps: 5,
                isCompleted: false
            )
        ]

        let summary = calculator.summarizeExerciseProgress(
            for: exerciseID,
            exerciseName: "Deadlift",
            samples: samples
        )

        XCTAssertEqual(summary.dataAvailability, .insufficient)
        XCTAssertNil(summary.bestWeight)
        XCTAssertNil(summary.bestReps)
    }

    func test_summarizeExerciseProgress_returnsPartialWhenOnlyWeightExists() {
        let exerciseID = UUID()
        let session0 = UUID()
        let day0 = Date(timeIntervalSince1970: 1_700_000_000)

        let samples = [
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Carry",
                sessionID: session0,
                sessionStartedAt: day0,
                performedAt: day0,
                segment: .main,
                weight: 80,
                reps: nil
            )
        ]

        let summary = calculator.summarizeExerciseProgress(
            for: exerciseID,
            exerciseName: "Carry",
            samples: samples
        )

        XCTAssertEqual(summary.dataAvailability, .partial)
        XCTAssertEqual(try XCTUnwrap(summary.bestWeight).value, 80, accuracy: 0.000_1)
        XCTAssertNil(summary.bestEstimatedOneRepMax)
    }

    func test_summarizeExerciseProgress_prefersMostRecentOnTies() {
        let exerciseID = UUID()
        let olderSession = UUID()
        let newerSession = UUID()
        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        let day1 = day0.addingTimeInterval(86_400)

        let samples = [
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: olderSession,
                sessionStartedAt: day0,
                performedAt: day0,
                segment: .main,
                weight: 100,
                reps: 5
            ),
            ExercisePerformanceSample(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessionID: newerSession,
                sessionStartedAt: day1,
                performedAt: day1,
                segment: .main,
                weight: 100,
                reps: 5
            )
        ]

        let summary = calculator.summarizeExerciseProgress(
            for: exerciseID,
            exerciseName: "Bench Press",
            samples: samples
        )

        XCTAssertEqual(summary.bestWeight?.sessionID, newerSession)
        XCTAssertEqual(summary.bestReps?.sessionID, newerSession)
    }
}
