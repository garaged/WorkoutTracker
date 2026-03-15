import Foundation

struct WeeklyVolumeCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func weeklySummaries(
        from samples: [ExercisePerformanceSample],
        includeAllSegmentsForOverallSummary: Bool = true
    ) -> [WeeklyTrainingSummary] {
        let eligible = samples.filter { sample in
            guard sample.isCompleted else { return false }
            if includeAllSegmentsForOverallSummary { return true }
            return sample.segment == .main
        }

        let grouped = Dictionary(grouping: eligible, by: weekStart(for:))

        return grouped.keys.sorted().map { weekStart in
            let weekSamples = grouped[weekStart] ?? []

            let workoutsCompleted = Set(weekSamples.map(\.sessionID)).count
            let totalSets = weekSamples.count
            let totalReps = weekSamples.compactMap { positiveInt($0.reps) }.reduce(0, +)

            let loadValues = weekSamples.compactMap(loadValue(for:))
            let totalLoad = loadValues.isEmpty ? nil : loadValues.reduce(0, +)

            let distinctExerciseCount = Set(weekSamples.map(\.exerciseID)).count

            let availability: ProgressDataAvailability
            if totalSets == 0 {
                availability = .insufficient
            } else if totalLoad == nil {
                availability = .partial
            } else {
                availability = .full
            }

            return WeeklyTrainingSummary(
                weekStart: weekStart,
                workoutsCompleted: workoutsCompleted,
                totalSets: totalSets,
                totalReps: totalReps,
                totalLoad: totalLoad,
                distinctExerciseCount: distinctExerciseCount,
                totalDurationSeconds: nil,
                dataAvailability: availability
            )
        }
    }

    func exerciseVolumeTrend(
        for exerciseID: UUID,
        from samples: [ExercisePerformanceSample],
        includeNonMainSegments: Bool = false
    ) -> ExerciseVolumeTrendSummary {
        let filtered = samples.filter { sample in
            guard sample.exerciseID == exerciseID else { return false }
            guard sample.isCompleted else { return false }
            if includeNonMainSegments { return true }
            return sample.segment == .main
        }

        let exerciseName = filtered.first?.exerciseName ?? samples.first(where: { $0.exerciseID == exerciseID })?.exerciseName ?? "Exercise"

        let grouped = Dictionary(grouping: filtered, by: weekStart(for:))
        let buckets = grouped.keys.sorted().map { weekStart in
            let weekSamples = grouped[weekStart] ?? []
            let sets = weekSamples.count
            let reps = weekSamples.compactMap { positiveInt($0.reps) }.reduce(0, +)
            let loads = weekSamples.compactMap(loadValue(for:))
            let load = loads.isEmpty ? nil : loads.reduce(0, +)

            return ExerciseWeeklyVolumeBucket(
                weekStart: weekStart,
                sets: sets,
                reps: reps,
                load: load
            )
        }

        let totalSets = buckets.reduce(0) { $0 + $1.sets }
        let totalReps = buckets.reduce(0) { $0 + $1.reps }
        let totalLoadValues = buckets.compactMap { $0.load }
        let totalLoad = totalLoadValues.isEmpty ? nil : totalLoadValues.reduce(0, +)

        let trendDirection = self.trendDirection(from: buckets)
        let availability: ProgressDataAvailability
        if buckets.isEmpty {
            availability = .insufficient
        } else if buckets.count < 2 || totalLoad == nil {
            availability = .partial
        } else {
            availability = .full
        }

        return ExerciseVolumeTrendSummary(
            exerciseID: exerciseID,
            exerciseName: exerciseName,
            weeklyBuckets: buckets,
            totalSets: totalSets,
            totalReps: totalReps,
            totalLoad: totalLoad,
            trendDirection: trendDirection,
            dataAvailability: availability
        )
    }

    private func weekStart(for sample: ExercisePerformanceSample) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: sample.performedAt)?.start ?? sample.performedAt
    }

    private func loadValue(for sample: ExercisePerformanceSample) -> Double? {
        guard let weight = positiveDouble(sample.weight), let reps = positiveInt(sample.reps) else {
            return nil
        }
        return weight * Double(reps)
    }

    private func positiveDouble(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func positiveInt(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func trendDirection(from buckets: [ExerciseWeeklyVolumeBucket]) -> ExerciseVolumeTrendDirection {
        let meaningful = buckets.filter { ($0.load ?? 0) > 0 || $0.sets > 0 || $0.reps > 0 }
        guard meaningful.count >= 2 else { return .insufficientData }

        let previous = trendValue(for: meaningful[meaningful.count - 2])
        let latest = trendValue(for: meaningful[meaningful.count - 1])

        if latest > previous { return .up }
        if latest < previous { return .down }
        return .flat
    }

    private func trendValue(for bucket: ExerciseWeeklyVolumeBucket) -> Double {
        if let load = bucket.load, load > 0 { return load }
        if bucket.reps > 0 { return Double(bucket.reps) }
        return Double(bucket.sets)
    }
}
