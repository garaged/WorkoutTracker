import Foundation
import SwiftData
import Combine

@MainActor
final class ProgressDashboardViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case emptyNoWorkouts
        case lowData(DashboardContent)
        case content(DashboardContent)
        case failed(String)
    }

    struct DashboardContent: Equatable {
        let summary: ProgressDashboardSummary
        let strength: StrengthCardModel
        let volume: VolumeCardModel
        let consistency: ConsistencyCardModel
        let recovery: RecoveryCardModel
        let windowTitle: String
    }

    struct StrengthCardModel: Equatable {
        struct ExerciseHighlight: Identifiable, Equatable {
            let exerciseID: UUID
            let exerciseName: String
            let badgeText: String
            let detailText: String
            let availability: ProgressDataAvailability

            var id: UUID { exerciseID }
        }

        let availability: ProgressDataAvailability
        let headline: String
        let summaryText: String
        let exercises: [ExerciseHighlight]
        let emptyMessage: String?
    }

    struct VolumeCardModel: Equatable {
        let availability: ProgressDataAvailability
        let headline: String
        let primaryValue: String
        let supportingText: String
        let stats: [Stat]
        let emptyMessage: String?
    }

    struct ConsistencyCardModel: Equatable {
        let availability: ProgressDataAvailability
        let headline: String
        let activeWeeksText: String
        let averageText: String
        let completionText: String?
        let supportingText: String
        let emptyMessage: String?
    }

    struct RecoveryCardModel: Equatable {
        let availability: ProgressDataAvailability
        let headline: String
        let sessionDurationText: String
        let plannedRestText: String?
        let actualRestText: String?
        let comparisonText: String
        let emptyMessage: String?
    }

    struct Stat: Identifiable, Equatable {
        let label: String
        let value: String

        var id: String { label }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var selectedExerciseID: UUID?

    private var service: (any ProgressAnalyticsServicing)?
    private var modelContext: ModelContext?
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
        modelContext = context
        guard service == nil else { return }

        service = ProgressAnalyticsService(
            context: context,
            weeklyVolumeCalculator: WeeklyVolumeCalculator(calendar: calendar),
            consistencyCalculator: ConsistencyCalculator(calendar: calendar)
        )
    }

    func load() {
        guard let service else {
            state = .failed(localized("progress.dashboard.unavailable"))
            return
        }

        state = .loading

        do {
            let summary = try service.dashboardSummary(for: dashboardWindow())
            state = map(summary: localizedSummary(summary))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() {
        load()
    }

    func openExerciseDetail(exerciseID: UUID) {
        selectedExerciseID = exerciseID
    }

    func clearExerciseSelection() {
        selectedExerciseID = nil
    }

    func localizedWindowLabel(_ value: String) -> String {
        localizedFormat("progress.dashboard.window.value", value)
    }

    private func map(summary: ProgressDashboardSummary) -> State {
        guard !summary.isEmpty else {
            return .emptyNoWorkouts
        }

        let content = DashboardContent(
            summary: summary,
            strength: makeStrengthCard(from: summary),
            volume: makeVolumeCard(from: summary),
            consistency: makeConsistencyCard(from: summary),
            recovery: makeRecoveryCard(from: summary),
            windowTitle: makeWindowTitle()
        )

        if summary.hasLowData {
            return .lowData(content)
        }

        return .content(content)
    }

    private func localizedSummary(_ summary: ProgressDashboardSummary) -> ProgressDashboardSummary {
        let exercisesByID = currentExercisesByID

        let featuredExercises = summary.featuredExercises.map { exercise in
            ExerciseProgressSummary(
                exerciseID: exercise.exerciseID,
                exerciseName: ExerciseLocalizationService.displayName(
                    exerciseID: exercise.exerciseID,
                    fallbackName: exercise.exerciseName,
                    exercisesByID: exercisesByID
                ),
                bestWeight: exercise.bestWeight,
                bestReps: exercise.bestReps,
                bestSetVolume: exercise.bestSetVolume,
                bestSessionVolume: exercise.bestSessionVolume,
                bestEstimatedOneRepMax: exercise.bestEstimatedOneRepMax,
                latestTopSet: exercise.latestTopSet,
                latestPerformedAt: exercise.latestPerformedAt,
                personalRecords: exercise.personalRecords,
                dataAvailability: exercise.dataAvailability
            )
        }

        let efficiency = summary.efficiency.map { efficiency in
            SessionEfficiencySummary(
                averageSessionDurationSeconds: efficiency.averageSessionDurationSeconds,
                averagePlannedRestSeconds: efficiency.averagePlannedRestSeconds,
                averageActualRestSeconds: efficiency.averageActualRestSeconds,
                averageRestOverrunSeconds: efficiency.averageRestOverrunSeconds,
                highestAverageRestOverrunExercises: efficiency.highestAverageRestOverrunExercises.map { exercise in
                    SessionEfficiencySummary.ExerciseRestOverrunSummary(
                        exerciseID: exercise.exerciseID,
                        exerciseName: ExerciseLocalizationService.displayName(
                            exerciseID: exercise.exerciseID,
                            fallbackName: exercise.exerciseName,
                            exercisesByID: exercisesByID
                        ),
                        averageOverrunSeconds: exercise.averageOverrunSeconds,
                        sampleCount: exercise.sampleCount
                    )
                },
                availability: efficiency.availability
            )
        }

        return ProgressDashboardSummary(
            featuredExercises: featuredExercises,
            weeklySummary: summary.weeklySummary,
            consistency: summary.consistency,
            efficiency: efficiency,
            dataAvailability: summary.dataAvailability,
            isEmpty: summary.isEmpty,
            hasLowData: summary.hasLowData
        )
    }

    private var currentExercisesByID: [UUID: Exercise] {
        guard let modelContext else { return [:] }
        return ExerciseLocalizationService.loadExercisesByID(context: modelContext)
    }

    private func dashboardWindow() -> DateInterval {
        let end = calendar.startOfDay(for: now())
        let start = calendar.date(byAdding: .day, value: -(windowWeeks * 7), to: end) ?? end
        return DateInterval(start: start, end: end)
    }

    private func makeWindowTitle() -> String {
        let end = calendar.startOfDay(for: now())
        let start = calendar.date(byAdding: .day, value: -(windowWeeks * 7), to: end) ?? end
        let endInclusive = calendar.date(byAdding: .day, value: -1, to: end) ?? end

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM d")

        let startText = formatter.string(from: start)
        let endText = formatter.string(from: endInclusive)
        return "\(startText) – \(endText)"
    }

    private func makeStrengthCard(from summary: ProgressDashboardSummary) -> StrengthCardModel {
        let featured = summary.featuredExercises

        guard !featured.isEmpty else {
            return StrengthCardModel(
                availability: .insufficient,
                headline: localized("progress.dashboard.strength.empty_headline"),
                summaryText: localized("progress.dashboard.strength.empty_summary"),
                exercises: [],
                emptyMessage: localized("progress.dashboard.strength.empty_message")
            )
        }

        let newPRCount = featured.reduce(0) { partialResult, exercise in
            partialResult + exercise.personalRecords.filter(\.isNewRecord).count
        }

        let headline: String
        if newPRCount > 0 {
            let key = newPRCount == 1
                ? "progress.dashboard.strength.headline.recent_prs.one"
                : "progress.dashboard.strength.headline.recent_prs.other"
            headline = localizedFormat(key, Int64(newPRCount))
        } else if featured.count == 1 {
            headline = featured[0].exerciseName
        } else {
            let key = featured.count == 1
                ? "progress.dashboard.strength.headline.featured_exercises.one"
                : "progress.dashboard.strength.headline.featured_exercises.other"
            headline = localizedFormat(key, Int64(featured.count))
        }

        let exercises = featured.map { exercise in
            StrengthCardModel.ExerciseHighlight(
                exerciseID: exercise.exerciseID,
                exerciseName: exercise.exerciseName,
                badgeText: strengthBadgeText(for: exercise),
                detailText: highlightText(for: exercise),
                availability: exercise.dataAvailability
            )
        }

        let topName = featured.first?.exerciseName ?? localized("progress.dashboard.strength.top_name_fallback")
        let summaryText: String
        if newPRCount > 0 {
            summaryText = localizedFormat("progress.dashboard.strength.summary.with_pr", topName)
        } else {
            let key = featured.count == 1
                ? "progress.dashboard.strength.summary.without_pr.one"
                : "progress.dashboard.strength.summary.without_pr.other"
            summaryText = localizedFormat(key, Int64(featured.count))
        }

        return StrengthCardModel(
            availability: aggregateAvailability(featured.map(\.dataAvailability)),
            headline: headline,
            summaryText: summaryText,
            exercises: exercises,
            emptyMessage: nil
        )
    }

    private func makeVolumeCard(from summary: ProgressDashboardSummary) -> VolumeCardModel {
        guard let weekly = summary.weeklySummary else {
            return VolumeCardModel(
                availability: .insufficient,
                headline: localized("progress.dashboard.volume.empty_headline"),
                primaryValue: "—",
                supportingText: localized("progress.dashboard.volume.empty_support"),
                stats: [],
                emptyMessage: localized("progress.dashboard.volume.empty_message")
            )
        }

        let primaryValue: String
        if let totalLoad = weekly.totalLoad {
            primaryValue = formatNumber(totalLoad)
        } else {
            primaryValue = localizedFormat("progress.dashboard.volume.primary.sets", Int64(weekly.totalSets))
        }

        let stats = [
            Stat(label: localized("progress.dashboard.volume.stat.workouts"), value: AppFormatting.integer(weekly.workoutsCompleted, locale: locale)),
            Stat(label: localized("progress.dashboard.volume.stat.sets"), value: AppFormatting.integer(weekly.totalSets, locale: locale)),
            Stat(label: localized("progress.dashboard.volume.stat.reps"), value: AppFormatting.integer(weekly.totalReps, locale: locale)),
            Stat(label: localized("progress.dashboard.volume.stat.exercises"), value: AppFormatting.integer(weekly.distinctExerciseCount, locale: locale))
        ]

        let supportingText: String
        if let duration = weekly.totalDurationSeconds {
            supportingText = localizedFormat(
                "progress.dashboard.volume.support.with_duration",
                Int64(weekly.totalSets),
                Int64(weekly.totalReps),
                Int64(weekly.workoutsCompleted),
                AppFormatting.shortDuration(seconds: duration, locale: locale)
            )
        } else {
            supportingText = localizedFormat(
                "progress.dashboard.volume.support.without_duration",
                Int64(weekly.totalSets),
                Int64(weekly.totalReps),
                Int64(weekly.workoutsCompleted)
            )
        }

        return VolumeCardModel(
            availability: weekly.dataAvailability,
            headline: localized("progress.dashboard.volume.headline"),
            primaryValue: primaryValue,
            supportingText: supportingText,
            stats: stats,
            emptyMessage: weekly.dataAvailability == .insufficient ? localized("progress.dashboard.volume.more_weeks_needed") : nil
        )
    }

    private func makeConsistencyCard(from summary: ProgressDashboardSummary) -> ConsistencyCardModel {
        let consistency = summary.consistency
        let activeWeeksText = localizedFormat(
            "progress.dashboard.consistency.active_weeks",
            Int64(consistency.activeWeeks),
            Int64(consistency.totalWeeks)
        )
        let averageText = localizedFormat(
            "progress.dashboard.consistency.average",
            formatNumber(consistency.averageWorkoutsPerWeek)
        )
        let completionText = consistency.completionRate.map {
            localizedFormat("progress.dashboard.consistency.completion", formatPercent($0))
        }

        let supportingText: String
        switch consistency.dataAvailability {
        case .full:
            supportingText = localized("progress.dashboard.consistency.support.full")
        case .partial:
            supportingText = localized("progress.dashboard.consistency.support.partial")
        case .insufficient:
            supportingText = localized("progress.dashboard.consistency.support.insufficient")
        }

        return ConsistencyCardModel(
            availability: consistency.dataAvailability,
            headline: localized("progress.dashboard.consistency.headline"),
            activeWeeksText: activeWeeksText,
            averageText: averageText,
            completionText: completionText,
            supportingText: supportingText,
            emptyMessage: consistency.dataAvailability == .insufficient
                ? localized("progress.dashboard.consistency.empty_message")
                : nil
        )
    }

    private func makeRecoveryCard(from summary: ProgressDashboardSummary) -> RecoveryCardModel {
        guard let efficiency = summary.efficiency else {
            return RecoveryCardModel(
                availability: .insufficient,
                headline: localized("progress.dashboard.recovery.headline"),
                sessionDurationText: "—",
                plannedRestText: nil,
                actualRestText: nil,
                comparisonText: localized("progress.dashboard.recovery.empty_support"),
                emptyMessage: localized("progress.dashboard.recovery.empty_message")
            )
        }

        let durationText = efficiency.averageSessionDurationSeconds.map(formatDuration(seconds:)) ?? "—"
        let plannedRestText = efficiency.averagePlannedRestSeconds.map { AppFormatting.shortDuration(seconds: Int($0.rounded()), locale: locale) }
        let actualRestText = efficiency.averageActualRestSeconds.map { AppFormatting.shortDuration(seconds: Int($0.rounded()), locale: locale) }

        let comparisonText: String
        if let overrun = efficiency.averageRestOverrunSeconds {
            let rounded = Int(overrun.rounded())
            if rounded > 0 {
                comparisonText = localizedFormat(
                    "progress.dashboard.recovery.comparison.longer",
                    AppFormatting.shortDuration(seconds: rounded, locale: locale)
                )
            } else if rounded < 0 {
                comparisonText = localizedFormat(
                    "progress.dashboard.recovery.comparison.earlier",
                    AppFormatting.shortDuration(seconds: abs(rounded), locale: locale)
                )
            } else {
                comparisonText = localized("progress.dashboard.recovery.comparison.matched")
            }
        } else if efficiency.availability == .partial {
            comparisonText = localized("progress.dashboard.recovery.comparison.partial")
        } else {
            comparisonText = localized("progress.dashboard.recovery.comparison.building")
        }

        return RecoveryCardModel(
            availability: efficiency.availability,
            headline: localized("progress.dashboard.recovery.headline"),
            sessionDurationText: durationText,
            plannedRestText: plannedRestText,
            actualRestText: actualRestText,
            comparisonText: comparisonText,
            emptyMessage: efficiency.availability == .partial && efficiency.averageRestOverrunSeconds == nil
                ? localized("progress.dashboard.recovery.partial_message")
                : nil
        )
    }

    private func strengthBadgeText(for exercise: ExerciseProgressSummary) -> String {
        if exercise.personalRecords.contains(where: \.isNewRecord) {
            return localized("progress.dashboard.strength.badge.pr")
        }

        if let bestWeight = exercise.bestWeight {
            return localizedFormat("progress.dashboard.strength.badge.best", formatNumber(bestWeight.value))
        }

        if let estimatedOneRepMax = exercise.bestEstimatedOneRepMax {
            return localizedFormat("progress.dashboard.strength.badge.estimated_1rm", formatNumber(estimatedOneRepMax.value))
        }

        return localized(exercise.dataAvailability == .partial
            ? "progress.dashboard.strength.badge.early"
            : "progress.availability.ready")
    }

    private func highlightText(for exercise: ExerciseProgressSummary) -> String {
        if let bestWeight = exercise.bestWeight {
            return localizedFormat("progress.dashboard.strength.highlight.best_weight", formatNumber(bestWeight.value))
        }

        if let estimatedOneRepMax = exercise.bestEstimatedOneRepMax {
            return localizedFormat("progress.dashboard.strength.highlight.best_estimated_1rm", formatNumber(estimatedOneRepMax.value))
        }

        if let topSet = exercise.latestTopSet,
           let reps = topSet.reps,
           let weight = topSet.weight {
            return localizedFormat(
                "progress.dashboard.strength.highlight.latest_top_set",
                Int64(reps),
                formatNumber(weight)
            )
        }

        if let performedAt = exercise.latestPerformedAt {
            return localizedFormat("progress.dashboard.strength.highlight.last_logged", AppFormatting.monthDay(performedAt, locale: locale))
        }

        return localized("progress.dashboard.strength.highlight.history_building")
    }

    private func aggregateAvailability(_ values: [ProgressDataAvailability]) -> ProgressDataAvailability {
        guard !values.isEmpty else { return .insufficient }
        if values.allSatisfy({ $0 == .full }) { return .full }
        if values.contains(where: { $0 != .insufficient }) { return .partial }
        return .insufficient
    }

    private func formatDuration(seconds: Double) -> String {
        AppFormatting.shortDuration(seconds: Int(seconds.rounded()), locale: locale)
    }

    private func formatNumber(_ value: Double) -> String {
        AppFormatting.decimal(value, maxFractionDigits: 1, locale: locale)
    }

    private func formatPercent(_ value: Double) -> String {
        AppFormatting.percent(value, maxFractionDigits: 0, locale: locale)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        String(format: localized(key), locale: locale, arguments: args)
    }
}
