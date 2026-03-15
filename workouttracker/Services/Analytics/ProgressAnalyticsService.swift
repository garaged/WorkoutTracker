import Foundation
import SwiftData

@MainActor
protocol ProgressAnalyticsServicing {
    func dashboardSummary(for window: DateInterval) throws -> ProgressDashboardSummary
    func exerciseDetailSummary(for exerciseID: UUID, window: DateInterval?) throws -> ExerciseProgressDetailSummary
}

@MainActor
final class ProgressAnalyticsService: ProgressAnalyticsServicing {
    private let dataSource: any ProgressAnalyticsDataSource
    private let personalRecordCalculator: PersonalRecordCalculator
    private let weeklyVolumeCalculator: WeeklyVolumeCalculator
    private let consistencyCalculator: ConsistencyCalculator
    private let sessionEfficiencyCalculator: SessionEfficiencyCalculator
    private let maxFeaturedExercises: Int
    private let recentSampleLimit: Int

    init(
        dataSource: any ProgressAnalyticsDataSource,
        personalRecordCalculator: PersonalRecordCalculator = PersonalRecordCalculator(),
        weeklyVolumeCalculator: WeeklyVolumeCalculator = WeeklyVolumeCalculator(),
        consistencyCalculator: ConsistencyCalculator = ConsistencyCalculator(),
        sessionEfficiencyCalculator: SessionEfficiencyCalculator = SessionEfficiencyCalculator(),
        maxFeaturedExercises: Int = 5,
        recentSampleLimit: Int = 8
    ) {
        self.dataSource = dataSource
        self.personalRecordCalculator = personalRecordCalculator
        self.weeklyVolumeCalculator = weeklyVolumeCalculator
        self.consistencyCalculator = consistencyCalculator
        self.sessionEfficiencyCalculator = sessionEfficiencyCalculator
        self.maxFeaturedExercises = maxFeaturedExercises
        self.recentSampleLimit = recentSampleLimit
    }

    convenience init(
        context: ModelContext,
        personalRecordCalculator: PersonalRecordCalculator = PersonalRecordCalculator(),
        weeklyVolumeCalculator: WeeklyVolumeCalculator = WeeklyVolumeCalculator(),
        consistencyCalculator: ConsistencyCalculator = ConsistencyCalculator(),
        sessionEfficiencyCalculator: SessionEfficiencyCalculator = SessionEfficiencyCalculator(),
        maxFeaturedExercises: Int = 5,
        recentSampleLimit: Int = 8
    ) {
        self.init(
            dataSource: DefaultProgressAnalyticsDataSource(context: context),
            personalRecordCalculator: personalRecordCalculator,
            weeklyVolumeCalculator: weeklyVolumeCalculator,
            consistencyCalculator: consistencyCalculator,
            sessionEfficiencyCalculator: sessionEfficiencyCalculator,
            maxFeaturedExercises: maxFeaturedExercises,
            recentSampleLimit: recentSampleLimit
        )
    }

    func dashboardSummary(for window: DateInterval) throws -> ProgressDashboardSummary {
        let performanceSamples = try dataSource.loadPerformanceSamples(in: window)
        let completedSessions = try dataSource.loadSessionAnalyticsSamples(in: window)

        let featuredExercises = featuredExerciseSummaries(from: performanceSamples)
        let weeklySummary = weeklyVolumeCalculator.weeklySummaries(from: performanceSamples).last
        let consistency = consistencyCalculator.summary(from: completedSessions, window: window)

        let efficiencySummary = sessionEfficiencyCalculator.summary(
            from: performanceSamples,
            sessions: completedSessions
        )
        let efficiency = efficiencySummary.availability == ProgressDataAvailability.insufficient
            ? nil
            : efficiencySummary

        let dataAvailability = dashboardAvailability(
            featuredExercises: featuredExercises,
            weeklySummary: weeklySummary,
            consistency: consistency,
            efficiency: efficiency
        )

        let isEmpty =
            featuredExercises.isEmpty &&
            weeklySummary == nil &&
            efficiency == nil &&
            consistency.dataAvailability == ProgressDataAvailability.insufficient

        return ProgressDashboardSummary(
            featuredExercises: featuredExercises,
            weeklySummary: weeklySummary,
            consistency: consistency,
            efficiency: efficiency,
            dataAvailability: dataAvailability,
            isEmpty: isEmpty,
            hasLowData: dataAvailability != ProgressDataAvailability.full
        )
    }

    func exerciseDetailSummary(for exerciseID: UUID, window: DateInterval? = nil) throws -> ExerciseProgressDetailSummary {
        let exerciseSamples = try dataSource.loadPerformanceSamples(for: exerciseID, in: window)

        let progress = personalRecordCalculator.summarizeExerciseProgress(
            for: exerciseID,
            samples: exerciseSamples
        )
        let weeklyVolumeTrend = weeklyVolumeCalculator.exerciseVolumeTrend(
            for: exerciseID,
            from: exerciseSamples
        )
        let recentPerformanceSamples = recentSamples(from: exerciseSamples)
        let estimatedOneRepMax = progress.bestEstimatedOneRepMax.map {
            ExerciseProgressDetailSummary.EstimatedOneRepMaxSummary(
                value: $0.value,
                achievedAt: $0.achievedAt,
                sessionID: $0.sessionID
            )
        }

        let availability = detailAvailability(
            progressAvailability: progress.dataAvailability,
            volumeAvailability: weeklyVolumeTrend.dataAvailability,
            recentPerformanceSamples: recentPerformanceSamples
        )

        return ExerciseProgressDetailSummary(
            exerciseID: progress.exerciseID,
            exerciseName: progress.exerciseName,
            personalRecords: progress.personalRecords,
            weeklyVolumeTrend: weeklyVolumeTrend,
            recentPerformanceSamples: recentPerformanceSamples,
            estimatedOneRepMax: estimatedOneRepMax,
            latestTopSet: progress.latestTopSet,
            dataAvailability: availability,
            hasLowData: availability != ProgressDataAvailability.full
        )
    }

    private func featuredExerciseSummaries(from samples: [ExercisePerformanceSample]) -> [ExerciseProgressSummary] {
        let grouped = Dictionary(grouping: samples, by: \.exerciseID)

        return grouped.keys.compactMap { exerciseID in
            let exerciseSamples = grouped[exerciseID] ?? []
            let summary = personalRecordCalculator.summarizeExerciseProgress(
                for: exerciseID,
                samples: exerciseSamples
            )
            return summary.dataAvailability == ProgressDataAvailability.insufficient ? nil : summary
        }
        .sorted { lhs, rhs in
            let lhsDate = lhs.latestPerformedAt ?? .distantPast
            let rhsDate = rhs.latestPerformedAt ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }

            let lhsAvailability = availabilityRank(lhs.dataAvailability)
            let rhsAvailability = availabilityRank(rhs.dataAvailability)
            if lhsAvailability != rhsAvailability { return lhsAvailability > rhsAvailability }

            return lhs.exerciseName.localizedCaseInsensitiveCompare(rhs.exerciseName) == .orderedAscending
        }
        .prefix(maxFeaturedExercises)
        .map { $0 }
    }

    private func recentSamples(from samples: [ExercisePerformanceSample]) -> [ExercisePerformanceSample] {
        let primary = samples.filter { $0.isCompleted && $0.segment == .main }
        let fallback = samples.filter(\.isCompleted)
        let source = primary.isEmpty ? fallback : primary

        return source
            .sorted { lhs, rhs in
                if lhs.performedAt != rhs.performedAt { return lhs.performedAt > rhs.performedAt }
                return lhs.id.uuidString > rhs.id.uuidString
            }
            .prefix(recentSampleLimit)
            .map { $0 }
    }

    private func dashboardAvailability(
        featuredExercises: [ExerciseProgressSummary],
        weeklySummary: WeeklyTrainingSummary?,
        consistency: ConsistencySummary,
        efficiency: SessionEfficiencySummary?
    ) -> ProgressDataAvailability {
        let availabilityStates: [ProgressDataAvailability] =
            featuredExercises.map(\.dataAvailability) +
            [
                weeklySummary?.dataAvailability,
                consistency.dataAvailability,
                efficiency?.availability
            ].compactMap { $0 }

        guard !availabilityStates.isEmpty else {
            return ProgressDataAvailability.insufficient
        }

        let hasMissingSection = featuredExercises.isEmpty || weeklySummary == nil || efficiency == nil

        if !hasMissingSection,
           availabilityStates.allSatisfy({ $0 == ProgressDataAvailability.full }) {
            return ProgressDataAvailability.full
        }

        if availabilityStates.contains(where: { $0 != ProgressDataAvailability.insufficient }) {
            return ProgressDataAvailability.partial
        }

        return ProgressDataAvailability.insufficient
    }

    private func detailAvailability(
        progressAvailability: ProgressDataAvailability,
        volumeAvailability: ProgressDataAvailability,
        recentPerformanceSamples: [ExercisePerformanceSample]
    ) -> ProgressDataAvailability {
        if progressAvailability == ProgressDataAvailability.full,
           volumeAvailability == ProgressDataAvailability.full {
            return ProgressDataAvailability.full
        }

        if progressAvailability != ProgressDataAvailability.insufficient ||
            volumeAvailability != ProgressDataAvailability.insufficient ||
            !recentPerformanceSamples.isEmpty {
            return ProgressDataAvailability.partial
        }

        return ProgressDataAvailability.insufficient
    }

    private func availabilityRank(_ availability: ProgressDataAvailability) -> Int {
        switch availability {
        case .full: return 2
        case .partial: return 1
        case .insufficient: return 0
        }
    }
}
