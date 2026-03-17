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
        let cards: [InsightCard]
        let unavailableSections: [UnavailableSection]
        let featuredExercises: [ExerciseRow]
        let windowTitle: String
    }

    struct InsightCard: Identifiable, Equatable {
        enum Kind: String, Equatable {
            case strength
            case volume
            case consistency
            case efficiency
        }

        let kind: Kind
        let title: String
        let value: String
        let subtitle: String
        let availability: ProgressDataAvailability

        var id: Kind { kind }
    }

    struct UnavailableSection: Identifiable, Equatable {
        enum Kind: String, Equatable {
            case strength
            case volume
            case consistency
            case efficiency
        }

        let kind: Kind
        let title: String
        let message: String

        var id: Kind { kind }
    }

    struct ExerciseRow: Identifiable, Equatable {
        let exerciseID: UUID
        let exerciseName: String
        let highlight: String
        let availability: ProgressDataAvailability

        var id: UUID { exerciseID }
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
            cards: makeCards(from: summary),
            unavailableSections: makeUnavailableSections(from: summary),
            featuredExercises: makeExerciseRows(from: summary.featuredExercises),
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

    private func makeCards(from summary: ProgressDashboardSummary) -> [InsightCard] {
        var cards: [InsightCard] = []

        if !summary.featuredExercises.isEmpty {
            let featured = summary.featuredExercises
            let topName = featured.first?.exerciseName ?? "Recent work"
            let subtitle: String
            if featured.contains(where: { $0.personalRecords.contains(where: \.isNewRecord) }) {
                subtitle = "Recent PR activity led by \(topName)."
            } else {
                subtitle = "Recent lifting history across \(featured.count) exercise\(featured.count == 1 ? "" : "s")."
            }

            cards.append(
                InsightCard(
                    kind: .strength,
                    title: "Strength",
                    value: "\(featured.count)",
                    subtitle: subtitle,
                    availability: aggregateAvailability(featured.map(\.dataAvailability))
                )
            )
        }

        if let weekly = summary.weeklySummary {
            let volumeValue: String
            if let load = weekly.totalLoad {
                volumeValue = formatNumber(load)
            } else {
                volumeValue = "\(weekly.totalSets) sets"
            }

            cards.append(
                InsightCard(
                    kind: .volume,
                    title: "Volume",
                    value: volumeValue,
                    subtitle: "Latest week: \(weekly.workoutsCompleted) workouts, \(weekly.totalSets) sets, \(weekly.totalReps) reps.",
                    availability: weekly.dataAvailability
                )
            )
        }

        let consistency = summary.consistency
        let completionDetail: String
        if let completionRate = consistency.completionRate {
            completionDetail = " Completion rate \(formatPercent(completionRate))."
        } else {
            completionDetail = ""
        }

        cards.append(
            InsightCard(
                kind: .consistency,
                title: "Consistency",
                value: "\(consistency.activeWeeks)/\(consistency.totalWeeks)",
                subtitle: "Avg \(formatNumber(consistency.averageWorkoutsPerWeek)) workouts/week.\(completionDetail)",
                availability: consistency.dataAvailability
            )
        )

        if let efficiency = summary.efficiency {
            let value = efficiency.averageSessionDurationSeconds.map(formatDuration(seconds:)) ?? "—"
            let restDetail: String
            if let overrun = efficiency.averageRestOverrunSeconds {
                let rounded = Int(overrun.rounded())
                if rounded > 0 {
                    restDetail = "Avg rest ran \(rounded)s long."
                } else if rounded < 0 {
                    restDetail = "Avg rest finished \(abs(rounded))s early."
                } else {
                    restDetail = "Rest matched plan on average."
                }
            } else {
                restDetail = "Rest timing is still building."
            }

            cards.append(
                InsightCard(
                    kind: .efficiency,
                    title: "Efficiency",
                    value: value,
                    subtitle: restDetail,
                    availability: efficiency.availability
                )
            )
        }

        return cards
    }

    private func makeUnavailableSections(from summary: ProgressDashboardSummary) -> [UnavailableSection] {
        var sections: [UnavailableSection] = []

        if summary.featuredExercises.isEmpty {
            sections.append(
                UnavailableSection(
                    kind: .strength,
                    title: "Strength",
                    message: "Log a few completed strength sets to unlock exercise highlights and PR trends."
                )
            )
        }

        if summary.weeklySummary == nil {
            sections.append(
                UnavailableSection(
                    kind: .volume,
                    title: "Volume",
                    message: "Complete more workouts in the selected window to build weekly volume totals."
                )
            )
        }

        if summary.consistency.dataAvailability == .insufficient {
            sections.append(
                UnavailableSection(
                    kind: .consistency,
                    title: "Consistency",
                    message: "A few completed sessions are needed before consistency trends can be trusted."
                )
            )
        }

        if summary.efficiency == nil {
            sections.append(
                UnavailableSection(
                    kind: .efficiency,
                    title: "Efficiency",
                    message: "Session timing and rest comparisons appear after enough finished sessions include timing data."
                )
            )
        }

        return sections
    }

    private func makeExerciseRows(from exercises: [ExerciseProgressSummary]) -> [ExerciseRow] {
        exercises.map { exercise in
            ExerciseRow(
                exerciseID: exercise.exerciseID,
                exerciseName: exercise.exerciseName,
                highlight: highlightText(for: exercise),
                availability: exercise.dataAvailability
            )
        }
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
        let totalMinutes = Int((seconds / 60).rounded())
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(minutes)m"
    }

    private func formatNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func formatPercent(_ value: Double) -> String {
        (value * 100).formatted(.number.precision(.fractionLength(0...0))) + "%"
    }
}
