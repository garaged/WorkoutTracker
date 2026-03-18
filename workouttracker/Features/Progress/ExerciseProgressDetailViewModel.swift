import Foundation
import SwiftData
import Combine

@MainActor
final class ExerciseProgressDetailViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case failed(String)
        case lowData(DetailContent)
        case content(DetailContent)
    }

    struct DetailContent: Equatable {
        let summary: ExerciseProgressDetailSummary
        let exerciseName: String
        let availability: ProgressDataAvailability
        let personalRecords: [PersonalRecordItem]
        let weeklyVolumeRows: [WeeklyVolumeRow]
        let recentPerformanceRows: [PerformanceRow]
        let estimatedOneRepMax: KeyMetric?
        let latestTopSet: KeyMetric?
        let lowDataMessage: String?
    }

    struct PersonalRecordItem: Identifiable, Equatable {
        let kind: PersonalRecordKind
        let title: String
        let valueText: String
        let subtitleText: String

        var id: PersonalRecordKind { kind }
    }

    struct WeeklyVolumeRow: Identifiable, Equatable {
        let weekStart: Date
        let title: String
        let valueText: String
        let subtitleText: String

        var id: Date { weekStart }
    }

    struct PerformanceRow: Identifiable, Equatable {
        let sampleID: UUID
        let title: String
        let valueText: String
        let subtitleText: String

        var id: UUID { sampleID }
    }

    struct KeyMetric: Equatable {
        let title: String
        let valueText: String
        let subtitleText: String
    }

    @Published private(set) var state: State = .idle

    private var service: (any ProgressAnalyticsServicing)?
    private let calendar: Calendar
    private let locale: Locale
    private let now: () -> Date
    private let windowWeeks: Int

    init(
        service: (any ProgressAnalyticsServicing)? = nil,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init,
        windowWeeks: Int = 12
    ) {
        self.service = service
        self.calendar = calendar
        self.locale = locale
        self.now = now
        self.windowWeeks = windowWeeks
    }

    func configureIfNeeded(context: ModelContext) {
        guard service == nil else { return }

        service = ProgressAnalyticsService(
            context: context,
            weeklyVolumeCalculator: WeeklyVolumeCalculator(calendar: calendar),
            consistencyCalculator: ConsistencyCalculator(calendar: calendar)
        )
    }

    func load(exerciseID: UUID) {
        guard let service else {
            state = .failed(localized("progress.detail.unavailable"))
            return
        }

        state = .loading

        do {
            let summary = try service.exerciseDetailSummary(
                for: exerciseID,
                window: detailWindow()
            )
            let content = makeContent(from: summary)
            state = summary.hasLowData ? .lowData(content) : .content(content)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh(exerciseID: UUID) {
        load(exerciseID: exerciseID)
    }

    private func detailWindow() -> DateInterval {
        let end = calendar.startOfDay(for: now())
        let start = calendar.date(byAdding: .day, value: -(windowWeeks * 7), to: end) ?? end
        return DateInterval(start: start, end: end)
    }

    private func makeContent(from summary: ExerciseProgressDetailSummary) -> DetailContent {
        DetailContent(
            summary: summary,
            exerciseName: summary.exerciseName,
            availability: summary.dataAvailability,
            personalRecords: summary.personalRecords.map(makePersonalRecordItem(from:)),
            weeklyVolumeRows: summary.weeklyVolumeTrend.weeklyBuckets
                .sorted { lhs, rhs in lhs.weekStart > rhs.weekStart }
                .prefix(6)
                .map(makeWeeklyVolumeRow(from:)),
            recentPerformanceRows: summary.recentPerformanceSamples.map(makePerformanceRow(from:)),
            estimatedOneRepMax: makeEstimatedOneRepMax(from: summary),
            latestTopSet: makeLatestTopSet(from: summary),
            lowDataMessage: lowDataMessage(for: summary)
        )
    }

    private func makePersonalRecordItem(from record: PersonalRecordSummary) -> PersonalRecordItem {
        let title: String
        switch record.kind {
        case .heaviestWeight:
            title = localized("progress.detail.personal_record.heaviest_weight")
        case .mostReps:
            title = localized("progress.detail.personal_record.most_reps")
        case .highestEstimatedOneRepMax:
            title = localized("progress.detail.personal_record.best_estimated_1rm")
        case .highestSessionVolume:
            title = localized("progress.detail.personal_record.best_session_volume")
        }

        let valueText: String
        switch record.kind {
        case .mostReps:
            let reps = Int(record.currentBest.rounded())
            if let contextWeight = record.contextWeight {
                valueText = localizedFormat(
                    "progress.detail.performance.value.reps_weight",
                    Int64(reps),
                    formatNumber(contextWeight)
                )
            } else {
                valueText = localizedFormat("progress.detail.performance.value.reps_only", Int64(reps))
            }
        default:
            valueText = formatNumber(record.currentBest)
        }

        var subtitleParts = [localizedFormat("progress.detail.personal_record.achieved", formatDate(record.achievedAt))]
        if let previous = record.previousBest {
            subtitleParts.append(localizedFormat("progress.detail.personal_record.previous", formatNumber(previous)))
        }
        if record.isNewRecord {
            subtitleParts.append(localized("progress.detail.personal_record.new_pr"))
        }

        return PersonalRecordItem(
            kind: record.kind,
            title: title,
            valueText: valueText,
            subtitleText: subtitleParts.joined(separator: " • ")
        )
    }

    private func makeWeeklyVolumeRow(from bucket: ExerciseWeeklyVolumeBucket) -> WeeklyVolumeRow {
        let title = localizedFormat("progress.detail.week.prefix", AppFormatting.monthDay(bucket.weekStart, locale: locale))
        let valueText: String
        if let load = bucket.load {
            valueText = localizedFormat("progress.detail.week.total_load", formatNumber(load))
        } else {
            valueText = localizedFormat("progress.detail.week.sets", Int64(bucket.sets))
        }

        let subtitleText = localizedFormat(
            "progress.detail.week.subtitle",
            Int64(bucket.sets),
            Int64(bucket.reps)
        )

        return WeeklyVolumeRow(
            weekStart: bucket.weekStart,
            title: title,
            valueText: valueText,
            subtitleText: subtitleText
        )
    }

    private func makePerformanceRow(from sample: ExercisePerformanceSample) -> PerformanceRow {
        let title = formatDate(sample.performedAt)

        let valueText: String
        if let reps = sample.reps, let weight = sample.weight {
            valueText = localizedFormat("progress.detail.performance.value.reps_weight", Int64(reps), formatNumber(weight))
        } else if let reps = sample.reps {
            valueText = localizedFormat("progress.detail.performance.value.reps_only", Int64(reps))
        } else if let weight = sample.weight {
            valueText = formatNumber(weight)
        } else {
            valueText = localized(sample.isCompleted ? "progress.detail.performance.value.completed_set" : "progress.detail.performance.value.logged_set")
        }

        var details = [String]()
        if let actualRest = sample.actualRestSeconds {
            details.append(localizedFormat(
                "progress.detail.performance.rest",
                AppFormatting.shortDuration(seconds: actualRest, locale: locale)
            ))
        } else if let plannedRest = sample.plannedRestSeconds {
            details.append(localizedFormat(
                "progress.detail.performance.planned_rest",
                AppFormatting.shortDuration(seconds: plannedRest, locale: locale)
            ))
        }

        if sample.segment != .main {
            details.append(segmentLabel(sample.segment))
        }

        return PerformanceRow(
            sampleID: sample.id,
            title: title,
            valueText: valueText,
            subtitleText: details.joined(separator: " • ")
        )
    }

    private func makeEstimatedOneRepMax(from summary: ExerciseProgressDetailSummary) -> KeyMetric? {
        guard let estimated = summary.estimatedOneRepMax else { return nil }
        return KeyMetric(
            title: localized("progress.detail.metric.estimated_1rm"),
            valueText: formatNumber(estimated.value),
            subtitleText: localizedFormat("progress.detail.metric.best_estimate_on", formatDate(estimated.achievedAt))
        )
    }

    private func makeLatestTopSet(from summary: ExerciseProgressDetailSummary) -> KeyMetric? {
        guard let topSet = summary.latestTopSet else { return nil }

        let valueText: String
        if let reps = topSet.reps, let weight = topSet.weight {
            valueText = localizedFormat("progress.detail.performance.value.reps_weight", Int64(reps), formatNumber(weight))
        } else if let reps = topSet.reps {
            valueText = localizedFormat("progress.detail.performance.value.reps_only", Int64(reps))
        } else if let weight = topSet.weight {
            valueText = formatNumber(weight)
        } else {
            valueText = localized("progress.detail.metric.logged_top_set")
        }

        var details = [localizedFormat("progress.detail.metric.logged_on", formatDate(topSet.performedAt))]
        if let estimated = topSet.estimatedOneRepMax {
            details.append(localizedFormat("progress.detail.metric.estimated_1rm_short", formatNumber(estimated)))
        }

        return KeyMetric(
            title: localized("progress.detail.metric.latest_top_set"),
            valueText: valueText,
            subtitleText: details.joined(separator: " • ")
        )
    }

    private func lowDataMessage(for summary: ExerciseProgressDetailSummary) -> String? {
        switch summary.dataAvailability {
        case .full:
            return nil
        case .partial:
            if summary.personalRecords.isEmpty && summary.recentPerformanceSamples.isEmpty {
                return localized("progress.detail.low_data.partial.empty")
            }
            return localized("progress.detail.low_data.partial.some")
        case .insufficient:
            return localized("progress.detail.low_data.insufficient")
        }
    }

    private func segmentLabel(_ segment: WorkoutExerciseSegment) -> String {
        switch segment {
        case .warmUp:
            return localized("session.segment.warm_up")
        case .main:
            return localized("session.segment.main")
        case .coolDown:
            return localized("session.segment.cool_down")
        }
    }

    private func formatNumber(_ value: Double) -> String {
        AppFormatting.decimal(value, maxFractionDigits: 1, locale: locale)
    }

    private func formatDate(_ date: Date) -> String {
        AppFormatting.monthDay(date, locale: locale)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        String(format: localized(key), locale: locale, arguments: args)
    }
}
