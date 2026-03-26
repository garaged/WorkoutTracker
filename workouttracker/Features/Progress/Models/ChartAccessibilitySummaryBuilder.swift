import Foundation

struct ChartAccessibilitySummary: Equatable {
    let headline: String
    let detail: String?
    let accessibilityLabel: String
    let accessibilityValue: String?
    let accessibilityHint: String?
    let isLowData: Bool
}

enum ChartAccessibilitySummaryBuilder {
    static func strengthCard(_ model: ProgressDashboardViewModel.StrengthCardModel) -> ChartAccessibilitySummary {
        let title = String(localized: "progress.dashboard.strength.title")
        let detail = nonEmpty(model.emptyMessage) ?? nonEmpty(model.summaryText)
        let valueParts = nonEmptyStrings(
            model.headline,
            detail,
            nonEmpty(model.summaryText),
            availabilityText(model.availability)
        )

        return ChartAccessibilitySummary(
            headline: model.headline,
            detail: detail,
            accessibilityLabel: title,
            accessibilityValue: valueParts.joined(separator: ". "),
            accessibilityHint: model.exercises.isEmpty ? nil : String(localized: "progress.dashboard.volume.open_exercise_detail"),
            isLowData: model.availability != .full
        )
    }

    static func volumeCard(_ model: ProgressDashboardViewModel.VolumeCardModel) -> ChartAccessibilitySummary {
        let title = String(localized: "progress.dashboard.volume.title")
        let detail = nonEmpty(model.supportingText) ?? nonEmpty(model.emptyMessage)
        let valueParts = nonEmptyStrings(
            model.headline,
            model.primaryValue,
            detail,
            availabilityText(model.availability)
        )

        return ChartAccessibilitySummary(
            headline: model.primaryValue,
            detail: detail,
            accessibilityLabel: title,
            accessibilityValue: valueParts.joined(separator: ". "),
            accessibilityHint: model.emptyMessage == nil ? String(localized: "progress.dashboard.volume.open_exercise_detail") : nil,
            isLowData: model.availability != .full
        )
    }

    static func consistencyCard(_ model: ProgressDashboardViewModel.ConsistencyCardModel) -> ChartAccessibilitySummary {
        let title = String(localized: "progress.dashboard.consistency.title")
        let detailParts = nonEmptyStrings(model.supportingText, model.completionText)
        let valueParts = nonEmptyStrings(
            model.headline,
            localizedMetric(String(localized: "progress.dashboard.consistency.stat.active_weeks"), value: model.activeWeeksText),
            localizedMetric(String(localized: "progress.dashboard.consistency.stat.average"), value: model.averageText)
        ) + detailParts + [availabilityText(model.availability)]

        return ChartAccessibilitySummary(
            headline: model.headline,
            detail: detailParts.first,
            accessibilityLabel: title,
            accessibilityValue: valueParts.joined(separator: ". "),
            accessibilityHint: nil,
            isLowData: model.availability != .full
        )
    }

    static func recoveryCard(_ model: ProgressDashboardViewModel.RecoveryCardModel) -> ChartAccessibilitySummary {
        let title = String(localized: "progress.dashboard.recovery.title")
        var valueParts = nonEmptyStrings(
            model.headline,
            localizedMetric(String(localized: "progress.dashboard.recovery.stat.avg_session"), value: model.sessionDurationText),
            model.comparisonText,
            availabilityText(model.availability)
        )

        if let plannedRestText = nonEmpty(model.plannedRestText) {
            valueParts.append(localizedMetric(String(localized: "progress.dashboard.recovery.stat.planned_rest"), value: plannedRestText))
        }
        if let actualRestText = nonEmpty(model.actualRestText) {
            valueParts.append(localizedMetric(String(localized: "progress.dashboard.recovery.stat.actual_rest"), value: actualRestText))
        }
        if let emptyMessage = nonEmpty(model.emptyMessage) {
            valueParts.append(emptyMessage)
        }

        return ChartAccessibilitySummary(
            headline: model.headline,
            detail: nonEmpty(model.comparisonText) ?? nonEmpty(model.emptyMessage),
            accessibilityLabel: title,
            accessibilityValue: valueParts.joined(separator: ". "),
            accessibilityHint: nil,
            isLowData: model.availability != .full
        )
    }

    static func exerciseVolumeTrend(
        _ summary: ExerciseVolumeTrendSummary,
        locale: Locale = .autoupdatingCurrent
    ) -> ChartAccessibilitySummary {
        let title = String(localized: "progress.detail.section.recent_volume")
        let bucketCount = summary.weeklyBuckets.count

        let headline: String
        if bucketCount < 2 || summary.trendDirection == .insufficientData {
            let key = bucketCount == 1
                ? "progress.a11y.summary.trend.limited.one"
                : "progress.a11y.summary.trend.limited.other"
            headline = String(
                format: AppFormatting.localized(key, locale: locale),
                locale: locale,
                Int64(bucketCount)
            )
        } else {
            let key: String
            switch summary.trendDirection {
            case .up:
                key = "progress.a11y.summary.trend.up"
            case .down:
                key = "progress.a11y.summary.trend.down"
            case .flat, .insufficientData:
                key = "progress.a11y.summary.trend.flat"
            }

            headline = String(
                format: AppFormatting.localized(key, locale: locale),
                locale: locale,
                summary.exerciseName,
                Int64(bucketCount)
            )
        }

        let detail: String?
        if let bestBucket = bestBucket(in: summary.weeklyBuckets) {
            detail = String(
                format: String(localized: "progress.a11y.summary.best_week"),
                locale: locale,
                stableMonthDay(bestBucket.weekStart, locale: locale)
            )
        } else {
            detail = nil
        }

        return ChartAccessibilitySummary(
            headline: headline,
            detail: detail,
            accessibilityLabel: title,
            accessibilityValue: nonEmptyStrings(headline, detail).joined(separator: ". "),
            accessibilityHint: nil,
            isLowData: summary.dataAvailability != .full || bucketCount < 2
        )
    }

    private static func bestBucket(in buckets: [ExerciseWeeklyVolumeBucket]) -> ExerciseWeeklyVolumeBucket? {
        buckets.max { lhs, rhs in
            bucketScore(lhs) < bucketScore(rhs)
        }
    }

    private static func bucketScore(_ bucket: ExerciseWeeklyVolumeBucket) -> Double {
        if let load = bucket.load {
            return load
        }
        return Double(bucket.reps) * 10 + Double(bucket.sets)
    }

    private static func availabilityText(_ availability: ProgressDataAvailability) -> String {
        switch availability {
        case .full:
            return String(localized: "progress.availability.ready")
        case .partial:
            return String(localized: "progress.availability.low_data")
        case .insufficient:
            return String(localized: "progress.availability.unavailable")
        }
    }

    private static func localizedMetric(_ title: String, value: String) -> String {
        "\(title): \(value)"
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func nonEmptyStrings(_ parts: String?...) -> [String] {
        parts.compactMap { nonEmpty($0) }
    }

    private static func stableMonthDay(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }
}
