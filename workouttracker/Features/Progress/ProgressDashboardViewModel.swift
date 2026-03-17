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

    func load() {
        guard let service else {
            state = .failed("Progress isn’t available yet.")
            return
        }

        state = .loading

        do {
            let summary = try service.dashboardSummary(for: dashboardWindow())
            state = map(summary: summary)
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
                headline: "Strength highlights will appear here",
                summaryText: "As you complete more logged sets, this card will surface your most relevant exercises and PR moments.",
                exercises: [],
                emptyMessage: "Log a few completed strength sets to unlock exercise highlights, PRs, and latest top-set signals."
            )
        }

        let newPRCount = featured.reduce(0) { partialResult, exercise in
            partialResult + exercise.personalRecords.filter(\.isNewRecord).count
        }

        let headline: String
        if newPRCount > 0 {
            headline = "\(newPRCount) recent PR\(newPRCount == 1 ? "" : "s")"
        } else if featured.count == 1 {
            headline = featured[0].exerciseName
        } else {
            headline = "\(featured.count) featured exercises"
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

        let topName = featured.first?.exerciseName ?? "your recent work"
        let summaryText: String
        if newPRCount > 0 {
            summaryText = "Recent PR activity is led by \(topName). Tap an exercise to open the detail drill-down when it lands in PR12."
        } else {
            summaryText = "Recent logged strength work across \(featured.count) exercise\(featured.count == 1 ? "" : "s"). Tap an exercise to inspect its next detail view later."
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
                headline: "Weekly volume is still building",
                primaryValue: "—",
                supportingText: "This card uses the latest completed week in the selected window. More completed workouts will make the weekly picture useful.",
                stats: [],
                emptyMessage: "Complete more workouts in this window to build weekly sets, reps, and load totals."
            )
        }

        let primaryValue: String
        if let totalLoad = weekly.totalLoad {
            primaryValue = formatNumber(totalLoad)
        } else {
            primaryValue = "\(weekly.totalSets) sets"
        }

        let stats = [
            Stat(label: "Workouts", value: "\(weekly.workoutsCompleted)"),
            Stat(label: "Sets", value: "\(weekly.totalSets)"),
            Stat(label: "Reps", value: "\(weekly.totalReps)"),
            Stat(label: "Exercises", value: "\(weekly.distinctExerciseCount)")
        ]

        let supportingText: String
        if let duration = weekly.totalDurationSeconds {
            supportingText = "Latest completed week totals \(weekly.totalSets) sets and \(weekly.totalReps) reps across \(weekly.workoutsCompleted) workouts in \(AppFormatting.shortDuration(seconds: duration, locale: locale))."
        } else {
            supportingText = "Latest completed week totals \(weekly.totalSets) sets and \(weekly.totalReps) reps across \(weekly.workoutsCompleted) workouts."
        }

        return VolumeCardModel(
            availability: weekly.dataAvailability,
            headline: "Latest weekly volume",
            primaryValue: primaryValue,
            supportingText: supportingText,
            stats: stats,
            emptyMessage: weekly.dataAvailability == .insufficient ? "More completed weeks are needed before the volume trend becomes trustworthy." : nil
        )
    }

    private func makeConsistencyCard(from summary: ProgressDashboardSummary) -> ConsistencyCardModel {
        let consistency = summary.consistency
        let activeWeeksText = "\(consistency.activeWeeks)/\(consistency.totalWeeks) active weeks"
        let averageText = "\(formatNumber(consistency.averageWorkoutsPerWeek)) workouts / week"
        let completionText = consistency.completionRate.map { "\(formatPercent($0)) completion" }

        let supportingText: String
        switch consistency.dataAvailability {
        case .full:
            supportingText = "This window has enough finished sessions to treat the routine pattern as meaningful."
        case .partial:
            supportingText = "Your routine is starting to take shape, but a few more finished weeks will make this trend steadier."
        case .insufficient:
            supportingText = "You have some activity, but not enough completed sessions yet for a trusted consistency read."
        }

        return ConsistencyCardModel(
            availability: consistency.dataAvailability,
            headline: "Consistency",
            activeWeeksText: activeWeeksText,
            averageText: averageText,
            completionText: completionText,
            supportingText: supportingText,
            emptyMessage: consistency.dataAvailability == .insufficient
                ? "A few completed sessions are needed before consistency trends can be trusted."
                : nil
        )
    }

    private func makeRecoveryCard(from summary: ProgressDashboardSummary) -> RecoveryCardModel {
        guard let efficiency = summary.efficiency else {
            return RecoveryCardModel(
                availability: .insufficient,
                headline: "Recovery and efficiency",
                sessionDurationText: "—",
                plannedRestText: nil,
                actualRestText: nil,
                comparisonText: "Session timing and planned-vs-actual rest appear once enough completed sessions include timing data.",
                emptyMessage: "Not enough timing data yet. Finish more sessions with rest metadata to unlock this card."
            )
        }

        let durationText = efficiency.averageSessionDurationSeconds.map(formatDuration(seconds:)) ?? "—"
        let plannedRestText = efficiency.averagePlannedRestSeconds.map { AppFormatting.shortDuration(seconds: Int($0.rounded()), locale: locale) }
        let actualRestText = efficiency.averageActualRestSeconds.map { AppFormatting.shortDuration(seconds: Int($0.rounded()), locale: locale) }

        let comparisonText: String
        if let overrun = efficiency.averageRestOverrunSeconds {
            let rounded = Int(overrun.rounded())
            if rounded > 0 {
                comparisonText = "Average rest ran \(AppFormatting.shortDuration(seconds: rounded, locale: locale)) longer than planned."
            } else if rounded < 0 {
                comparisonText = "Average rest finished \(AppFormatting.shortDuration(seconds: abs(rounded), locale: locale)) earlier than planned."
            } else {
                comparisonText = "Average rest matched the plan closely."
            }
        } else if efficiency.availability == .partial {
            comparisonText = "Some timing data is present, but planned-vs-actual rest still needs more sessions."
        } else {
            comparisonText = "Rest timing is still building."
        }

        return RecoveryCardModel(
            availability: efficiency.availability,
            headline: "Recovery and efficiency",
            sessionDurationText: durationText,
            plannedRestText: plannedRestText,
            actualRestText: actualRestText,
            comparisonText: comparisonText,
            emptyMessage: efficiency.availability == .partial && efficiency.averageRestOverrunSeconds == nil
                ? "Efficiency has partial timing data, but rest comparison still needs more logged sessions."
                : nil
        )
    }

    private func strengthBadgeText(for exercise: ExerciseProgressSummary) -> String {
        if exercise.personalRecords.contains(where: \.isNewRecord) {
            return "PR"
        }

        if let bestWeight = exercise.bestWeight {
            return "Best \(formatNumber(bestWeight.value))"
        }

        if let estimatedOneRepMax = exercise.bestEstimatedOneRepMax {
            return "Est. 1RM \(formatNumber(estimatedOneRepMax.value))"
        }

        return exercise.dataAvailability == .partial ? "Early" : "Ready"
    }

    private func highlightText(for exercise: ExerciseProgressSummary) -> String {
        if let bestWeight = exercise.bestWeight {
            return "Best weight \(formatNumber(bestWeight.value))"
        }

        if let estimatedOneRepMax = exercise.bestEstimatedOneRepMax {
            return "Best est. 1RM \(formatNumber(estimatedOneRepMax.value))"
        }

        if let topSet = exercise.latestTopSet,
           let reps = topSet.reps,
           let weight = topSet.weight {
            return "Latest top set \(reps) × \(formatNumber(weight))"
        }

        if let performedAt = exercise.latestPerformedAt {
            return "Last logged \(performedAt.formatted(.dateTime.month(.abbreviated).day()))"
        }

        return "Progress history is still building"
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
}
