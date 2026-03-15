import Foundation

struct PersonalRecordCalculator {
    struct SessionSnapshot: Identifiable, Hashable {
        var id: UUID { sessionID }

        let sessionID: UUID
        let date: Date
        let sessionVolume: Double
        let bestSetVolume: Double
        let bestSetWeight: Double
        let bestEstimatedOneRepMax: Double
        let bestReps: Int
    }

    func summarizeExerciseProgress(
        for exerciseID: UUID,
        exerciseName: String? = nil,
        samples: [ExercisePerformanceSample],
        includeNonMainSegments: Bool = false
    ) -> ExerciseProgressSummary {
        let eligibleSamples = filteredSamples(samples, includeNonMainSegments: includeNonMainSegments)
        let resolvedName = exerciseName ?? eligibleSamples.first?.exerciseName ?? samples.first?.exerciseName ?? "Exercise"

        let bestWeight = bestWeightRecord(from: eligibleSamples)
        let bestReps = bestRepsRecord(from: eligibleSamples)
        let bestSetVolume = bestSetVolumeRecord(from: eligibleSamples)
        let bestEstimatedOneRepMax = bestEstimatedOneRepMaxRecord(from: eligibleSamples)
        let latestTopSet = latestTopSet(from: eligibleSamples)
        let latestPerformedAt = eligibleSamples.map(\.performedAt).max()
        let sessionSnapshots = sessionProgression(from: eligibleSamples)
        let bestSessionVolume = bestSessionVolumeRecord(from: sessionSnapshots)
        let personalRecords = personalRecordSummaries(
            samples: eligibleSamples,
            sessionSnapshots: sessionSnapshots
        )
        let availability = dataAvailability(
            bestWeight: bestWeight,
            bestReps: bestReps,
            bestSetVolume: bestSetVolume,
            bestSessionVolume: bestSessionVolume,
            bestEstimatedOneRepMax: bestEstimatedOneRepMax,
            latestTopSet: latestTopSet,
            eligibleSampleCount: eligibleSamples.count
        )

        return ExerciseProgressSummary(
            exerciseID: exerciseID,
            exerciseName: resolvedName,
            bestWeight: bestWeight,
            bestReps: bestReps,
            bestSetVolume: bestSetVolume,
            bestSessionVolume: bestSessionVolume,
            bestEstimatedOneRepMax: bestEstimatedOneRepMax,
            latestTopSet: latestTopSet,
            latestPerformedAt: latestPerformedAt,
            personalRecords: personalRecords,
            dataAvailability: availability
        )
    }

    func sessionProgression(
        from samples: [ExercisePerformanceSample],
        includeNonMainSegments: Bool = false
    ) -> [SessionSnapshot] {
        let eligibleSamples = filteredSamples(samples, includeNonMainSegments: includeNonMainSegments)
        return groupedSessionSnapshots(from: eligibleSamples)
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.sessionID.uuidString < rhs.sessionID.uuidString
            }
    }

    private func filteredSamples(
        _ samples: [ExercisePerformanceSample],
        includeNonMainSegments: Bool
    ) -> [ExercisePerformanceSample] {
        samples.filter { sample in
            guard sample.isCompleted else { return false }
            if includeNonMainSegments { return true }
            return sample.segment == .main
        }
    }

    private func groupedSessionSnapshots(from samples: [ExercisePerformanceSample]) -> [SessionSnapshot] {
        let grouped = Dictionary(grouping: samples, by: \.sessionID)

        return grouped.values.compactMap { sessionSamples in
            guard let first = sessionSamples.first else { return nil }

            let volumes = sessionSamples.compactMap(setVolume)
            let e1RMs = sessionSamples.compactMap { estimatedOneRepMaxValue(for: $0) }
            let weights = sessionSamples.compactMap { positiveDouble($0.weight) }
            let reps = sessionSamples.compactMap { positiveInt($0.reps) }

            let sessionVolume = volumes.reduce(0, +)
            let bestSetVolume = volumes.max() ?? 0
            let bestSetWeight = weights.max() ?? 0
            let bestEstimatedOneRepMax = e1RMs.max() ?? 0
            let bestReps = reps.max() ?? 0

            if sessionVolume <= 0, bestSetWeight <= 0, bestEstimatedOneRepMax <= 0, bestReps <= 0 {
                return nil
            }

            return SessionSnapshot(
                sessionID: first.sessionID,
                date: first.sessionStartedAt,
                sessionVolume: sessionVolume,
                bestSetVolume: bestSetVolume,
                bestSetWeight: bestSetWeight,
                bestEstimatedOneRepMax: bestEstimatedOneRepMax,
                bestReps: bestReps
            )
        }
    }

    private func bestWeightRecord(from samples: [ExercisePerformanceSample]) -> ExerciseProgressSummary.MetricSnapshot? {
        bestSample(
            from: samples,
            value: { positiveDouble($0.weight) },
            tieBreakDate: \.performedAt
        ).map { sample, value in
            ExerciseProgressSummary.MetricSnapshot(
                value: value,
                achievedAt: sample.performedAt,
                sessionID: sample.sessionID
            )
        }
    }

    private func bestRepsRecord(from samples: [ExercisePerformanceSample]) -> ExerciseProgressSummary.IntMetricSnapshot? {
        bestSample(
            from: samples,
            value: { positiveInt($0.reps) },
            tieBreakDate: \.performedAt
        ).map { sample, value in
            ExerciseProgressSummary.IntMetricSnapshot(
                value: value,
                achievedAt: sample.performedAt,
                sessionID: sample.sessionID,
                contextWeight: positiveDouble(sample.weight)
            )
        }
    }

    private func bestSetVolumeRecord(from samples: [ExercisePerformanceSample]) -> ExerciseProgressSummary.MetricSnapshot? {
        bestSample(
            from: samples,
            value: setVolume,
            tieBreakDate: \.performedAt
        ).map { sample, value in
            ExerciseProgressSummary.MetricSnapshot(
                value: value,
                achievedAt: sample.performedAt,
                sessionID: sample.sessionID
            )
        }
    }

    private func bestEstimatedOneRepMaxRecord(from samples: [ExercisePerformanceSample]) -> ExerciseProgressSummary.MetricSnapshot? {
        bestSample(
            from: samples,
            value: { estimatedOneRepMaxValue(for: $0) },
            tieBreakDate: \.performedAt
        ).map { sample, value in
            ExerciseProgressSummary.MetricSnapshot(
                value: value,
                achievedAt: sample.performedAt,
                sessionID: sample.sessionID
            )
        }
    }

    private func bestSessionVolumeRecord(from snapshots: [SessionSnapshot]) -> ExerciseProgressSummary.MetricSnapshot? {
        snapshots.reduce(into: nil as ExerciseProgressSummary.MetricSnapshot?) { current, snapshot in
            guard snapshot.sessionVolume > 0 else { return }
            let candidate = ExerciseProgressSummary.MetricSnapshot(
                value: snapshot.sessionVolume,
                achievedAt: snapshot.date,
                sessionID: snapshot.sessionID
            )
            if shouldReplace(current: current, candidate: candidate) {
                current = candidate
            }
        }
    }

    private func latestTopSet(from samples: [ExercisePerformanceSample]) -> ExerciseProgressSummary.TopSetSnapshot? {
        let grouped = Dictionary(grouping: samples, by: \.sessionID)
        guard let latestSessionSamples = grouped.values.max(by: compareSessionSamples) else { return nil }
        guard let bestLatestSet = latestSessionSamples.max(by: compareTopSetSamples) else { return nil }

        let estimated = estimatedOneRepMaxValue(for: bestLatestSet)
        let weight = positiveDouble(bestLatestSet.weight)
        let reps = positiveInt(bestLatestSet.reps)

        guard estimated != nil || weight != nil || reps != nil else { return nil }

        return ExerciseProgressSummary.TopSetSnapshot(
            performedAt: bestLatestSet.performedAt,
            sessionID: bestLatestSet.sessionID,
            weight: weight,
            reps: reps,
            estimatedOneRepMax: estimated
        )
    }

    private func personalRecordSummaries(
        samples: [ExercisePerformanceSample],
        sessionSnapshots: [SessionSnapshot]
    ) -> [PersonalRecordSummary] {
        var summaries: [PersonalRecordSummary] = []

        if let summary = recordSummary(
            kind: .heaviestWeight,
            overallBest: bestWeightRecord(from: samples),
            previousBest: previousBestSampleValue(from: samples, matchingSessionID: bestWeightRecord(from: samples)?.sessionID, value: { positiveDouble($0.weight) }),
            contextWeight: nil,
            latestSessionID: sessionSnapshots.last?.sessionID
        ) {
            summaries.append(summary)
        }

        if let bestReps = bestRepsRecord(from: samples) {
            summaries.append(PersonalRecordSummary(
                kind: .mostReps,
                previousBest: previousBestSampleValue(from: samples, matchingSessionID: bestReps.sessionID, value: { positiveDouble(Double($0.reps ?? 0)) }),
                currentBest: Double(bestReps.value),
                achievedAt: bestReps.achievedAt,
                sessionID: bestReps.sessionID,
                isNewRecord: isLatestSessionRecord(bestSessionID: bestReps.sessionID, latestSessionID: sessionSnapshots.last?.sessionID, currentBest: Double(bestReps.value), previousBest: previousBestSampleValue(from: samples, matchingSessionID: bestReps.sessionID, value: { positiveDouble(Double($0.reps ?? 0)) })),
                contextWeight: bestReps.contextWeight
            ))
        }

        if let summary = recordSummary(
            kind: .highestEstimatedOneRepMax,
            overallBest: bestEstimatedOneRepMaxRecord(from: samples),
            previousBest: previousBestSampleValue(from: samples, matchingSessionID: bestEstimatedOneRepMaxRecord(from: samples)?.sessionID, value: { estimatedOneRepMaxValue(for: $0) }),
            contextWeight: nil,
            latestSessionID: sessionSnapshots.last?.sessionID
        ) {
            summaries.append(summary)
        }

        if let bestSession = bestSessionVolumeRecord(from: sessionSnapshots) {
            let previousBest = sessionSnapshots
                .filter { $0.sessionID != bestSession.sessionID }
                .map(\.sessionVolume)
                .filter { $0 > 0 }
                .max()

            summaries.append(PersonalRecordSummary(
                kind: .highestSessionVolume,
                previousBest: previousBest,
                currentBest: bestSession.value,
                achievedAt: bestSession.achievedAt,
                sessionID: bestSession.sessionID,
                isNewRecord: isLatestSessionRecord(bestSessionID: bestSession.sessionID, latestSessionID: sessionSnapshots.last?.sessionID, currentBest: bestSession.value, previousBest: previousBest),
                contextWeight: nil
            ))
        }

        return summaries
    }

    private func recordSummary(
        kind: PersonalRecordKind,
        overallBest: ExerciseProgressSummary.MetricSnapshot?,
        previousBest: Double?,
        contextWeight: Double?,
        latestSessionID: UUID?
    ) -> PersonalRecordSummary? {
        guard let overallBest else { return nil }
        return PersonalRecordSummary(
            kind: kind,
            previousBest: previousBest,
            currentBest: overallBest.value,
            achievedAt: overallBest.achievedAt,
            sessionID: overallBest.sessionID,
            isNewRecord: isLatestSessionRecord(
                bestSessionID: overallBest.sessionID,
                latestSessionID: latestSessionID,
                currentBest: overallBest.value,
                previousBest: previousBest
            ),
            contextWeight: contextWeight
        )
    }

    private func previousBestSampleValue(
        from samples: [ExercisePerformanceSample],
        matchingSessionID: UUID?,
        value: (ExercisePerformanceSample) -> Double?
    ) -> Double? {
        guard let matchingSessionID else { return nil }
        return samples
            .filter { $0.sessionID != matchingSessionID }
            .compactMap(value)
            .filter { $0 > 0 }
            .max()
    }

    private func isLatestSessionRecord(
        bestSessionID: UUID,
        latestSessionID: UUID?,
        currentBest: Double,
        previousBest: Double?
    ) -> Bool {
        guard bestSessionID == latestSessionID else { return false }
        guard let previousBest else { return true }
        return currentBest > previousBest
    }

    private func dataAvailability(
        bestWeight: ExerciseProgressSummary.MetricSnapshot?,
        bestReps: ExerciseProgressSummary.IntMetricSnapshot?,
        bestSetVolume: ExerciseProgressSummary.MetricSnapshot?,
        bestSessionVolume: ExerciseProgressSummary.MetricSnapshot?,
        bestEstimatedOneRepMax: ExerciseProgressSummary.MetricSnapshot?,
        latestTopSet: ExerciseProgressSummary.TopSetSnapshot?,
        eligibleSampleCount: Int
    ) -> ProgressDataAvailability {
        guard eligibleSampleCount > 0 else { return .insufficient }

        let metrics: [Bool] = [
            bestWeight != nil,
            bestReps != nil,
            bestSetVolume != nil,
            bestSessionVolume != nil,
            bestEstimatedOneRepMax != nil,
            latestTopSet != nil
        ]

        if metrics.allSatisfy({ $0 }) {
            return .full
        }
        return .partial
    }

    private func compareSessionSamples(_ lhs: [ExercisePerformanceSample], _ rhs: [ExercisePerformanceSample]) -> Bool {
        let lhsDate = lhs.map(\.sessionStartedAt).max() ?? .distantPast
        let rhsDate = rhs.map(\.sessionStartedAt).max() ?? .distantPast
        if lhsDate != rhsDate { return lhsDate < rhsDate }
        let lhsID = lhs.first?.sessionID.uuidString ?? ""
        let rhsID = rhs.first?.sessionID.uuidString ?? ""
        return lhsID < rhsID
    }

    private func compareTopSetSamples(_ lhs: ExercisePerformanceSample, _ rhs: ExercisePerformanceSample) -> Bool {
        let lhsValue = estimatedOneRepMaxValue(for: lhs) ?? positiveDouble(lhs.weight) ?? Double(positiveInt(lhs.reps) ?? 0)
        let rhsValue = estimatedOneRepMaxValue(for: rhs) ?? positiveDouble(rhs.weight) ?? Double(positiveInt(rhs.reps) ?? 0)
        if lhsValue != rhsValue { return lhsValue < rhsValue }
        if lhs.performedAt != rhs.performedAt { return lhs.performedAt < rhs.performedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func bestSample<T: Comparable>(
        from samples: [ExercisePerformanceSample],
        value: (ExercisePerformanceSample) -> T?,
        tieBreakDate: KeyPath<ExercisePerformanceSample, Date>
    ) -> (ExercisePerformanceSample, T)? {
        samples.reduce(into: nil as (ExercisePerformanceSample, T)?) { current, sample in
            guard let candidateValue = value(sample) else { return }
            let candidate = (sample, candidateValue)
            guard let existing = current else {
                current = candidate
                return
            }
            if candidateValue > existing.1 {
                current = candidate
            } else if candidateValue == existing.1 {
                let existingDate = existing.0[keyPath: tieBreakDate]
                let candidateDate = sample[keyPath: tieBreakDate]
                if candidateDate > existingDate || (candidateDate == existingDate && sample.id.uuidString > existing.0.id.uuidString) {
                    current = candidate
                }
            }
        }
    }

    private func shouldReplace(
        current: ExerciseProgressSummary.MetricSnapshot?,
        candidate: ExerciseProgressSummary.MetricSnapshot
    ) -> Bool {
        guard let current else { return true }
        if candidate.value != current.value { return candidate.value > current.value }
        if candidate.achievedAt != current.achievedAt { return candidate.achievedAt > current.achievedAt }
        return candidate.sessionID.uuidString > current.sessionID.uuidString
    }

    private func positiveDouble(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func positiveInt(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func estimatedOneRepMaxValue(for sample: ExercisePerformanceSample) -> Double? {
        guard let weight = positiveDouble(sample.weight), let reps = positiveInt(sample.reps) else { return nil }
        return weight * (1.0 + (Double(reps) / 30.0))
    }

    private func setVolume(_ sample: ExercisePerformanceSample) -> Double? {
        guard let weight = positiveDouble(sample.weight), let reps = positiveInt(sample.reps) else { return nil }
        return weight * Double(reps)
    }
}
