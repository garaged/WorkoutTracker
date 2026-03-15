import Foundation

struct SessionEfficiencyCalculator {
    func summary(
        from samples: [ExercisePerformanceSample],
        sessions: [SessionAnalyticsSample],
        includeNonMainSegments: Bool = false,
        minimumExerciseSamples: Int = 2
    ) -> SessionEfficiencySummary {
        let eligibleSamples = samples.filter { sample in
            guard sample.isCompleted else { return false }
            if includeNonMainSegments { return true }
            return sample.segment == .main
        }

        let completedSessions = sessions.filter(\.wasCompleted)
        let durationValues = completedSessions.compactMap(positiveInt(\.durationSeconds))
        let plannedRestValues = eligibleSamples.compactMap(positiveInt(\.plannedRestSeconds))
        let actualRestValues = eligibleSamples.compactMap(positiveInt(\.actualRestSeconds))
        let overrunValues = eligibleSamples.compactMap(restOverrun(for:))

        let highestAverageRestOverrunExercises = highestAverageOverrunExercises(
            from: eligibleSamples,
            minimumExerciseSamples: minimumExerciseSamples
        )

        let averageSessionDuration = average(durationValues)
        let averagePlannedRest = average(plannedRestValues)
        let averageActualRest = average(actualRestValues)
        let averageRestOverrun = average(overrunValues)

        let hasAnyMetric =
            averageSessionDuration != nil ||
            averagePlannedRest != nil ||
            averageActualRest != nil ||
            averageRestOverrun != nil ||
            !highestAverageRestOverrunExercises.isEmpty

        let availability: ProgressDataAvailability
        if !hasAnyMetric {
            availability = .insufficient
        } else if averagePlannedRest != nil, averageActualRest != nil, averageRestOverrun != nil {
            availability = .full
        } else {
            availability = .partial
        }

        return SessionEfficiencySummary(
            averageSessionDurationSeconds: averageSessionDuration,
            averagePlannedRestSeconds: averagePlannedRest,
            averageActualRestSeconds: averageActualRest,
            averageRestOverrunSeconds: averageRestOverrun,
            highestAverageRestOverrunExercises: highestAverageRestOverrunExercises,
            availability: availability
        )
    }

    private func highestAverageOverrunExercises(
        from samples: [ExercisePerformanceSample],
        minimumExerciseSamples: Int
    ) -> [SessionEfficiencySummary.ExerciseRestOverrunSummary] {
        let grouped = Dictionary(grouping: samples, by: \.exerciseID)

        return grouped.values.compactMap { exerciseSamples in
            guard let first = exerciseSamples.first else { return nil }

            let overrunValues = exerciseSamples.compactMap(restOverrun(for:))
            guard overrunValues.count >= minimumExerciseSamples else { return nil }

            let averageOverrun = average(overrunValues)
            guard let averageOverrun, averageOverrun > 0 else { return nil }

            return SessionEfficiencySummary.ExerciseRestOverrunSummary(
                exerciseID: first.exerciseID,
                exerciseName: first.exerciseName,
                averageOverrunSeconds: averageOverrun,
                sampleCount: overrunValues.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.averageOverrunSeconds != rhs.averageOverrunSeconds {
                return lhs.averageOverrunSeconds > rhs.averageOverrunSeconds
            }
            if lhs.sampleCount != rhs.sampleCount {
                return lhs.sampleCount > rhs.sampleCount
            }
            return lhs.exerciseName.localizedCaseInsensitiveCompare(rhs.exerciseName) == .orderedAscending
        }
    }

    private func restOverrun(for sample: ExercisePerformanceSample) -> Double? {
        guard
            let planned = positiveInt(sample.plannedRestSeconds),
            let actual = positiveInt(sample.actualRestSeconds)
        else {
            return nil
        }

        return Double(actual - planned)
    }

    private func average(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func positiveInt(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func positiveInt(_ keyPath: KeyPath<SessionAnalyticsSample, Int?>) -> (SessionAnalyticsSample) -> Int? {
        { sample in
            positiveInt(sample[keyPath: keyPath])
        }
    }

    private func positiveInt(_ keyPath: KeyPath<ExercisePerformanceSample, Int?>) -> (ExercisePerformanceSample) -> Int? {
        { sample in
            positiveInt(sample[keyPath: keyPath])
        }
    }
}
