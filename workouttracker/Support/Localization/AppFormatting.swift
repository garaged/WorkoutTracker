import Foundation

// File: workouttracker/Support/Localization/AppFormatting.swift
//
// Why this file lives here:
// Formatting rules for durations, numbers, and dates are shared support logic.
// Keeping them out of views makes locale behavior consistent and easier to test.

enum AppFormatting {
    static func duration(seconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let absoluteSeconds = abs(seconds)
        let sign = seconds < 0 ? "-" : ""

        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60
        let remainingSeconds = absoluteSeconds % 60

        if hours > 0 {
            return sign + [
                localizedInteger(hours, locale: locale),
                localizedInteger(minutes, minimumIntegerDigits: 2, locale: locale),
                localizedInteger(remainingSeconds, minimumIntegerDigits: 2, locale: locale)
            ].joined(separator: ":")
        }

        return sign + [
            localizedInteger(minutes, locale: locale),
            localizedInteger(remainingSeconds, minimumIntegerDigits: 2, locale: locale)
        ].joined(separator: ":")
    }

    static func shortDuration(seconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let absoluteSeconds = abs(seconds)
        let sign = seconds < 0 ? "-" : ""

        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60
        let remainingSeconds = absoluteSeconds % 60

        if hours > 0 {
            if remainingSeconds == 0 {
                return sign + String(
                    format: String(localized: "format.duration.short.hours_minutes"),
                    localizedInteger(hours, locale: locale),
                    localizedInteger(minutes, locale: locale)
                )
            }

            return sign + String(
                format: String(localized: "format.duration.short.hours_minutes_seconds"),
                localizedInteger(hours, locale: locale),
                localizedInteger(minutes, locale: locale),
                localizedInteger(remainingSeconds, locale: locale)
            )
        }

        if absoluteSeconds < 60 {
            return sign + String(
                format: String(localized: "format.duration.short.seconds"),
                localizedInteger(absoluteSeconds, locale: locale)
            )
        }

        if remainingSeconds == 0 {
            return sign + String(
                format: String(localized: "format.duration.short.minutes"),
                localizedInteger(minutes, locale: locale)
            )
        }

        return sign + String(
            format: String(localized: "format.duration.short.minutes_seconds"),
            localizedInteger(minutes, locale: locale),
            localizedInteger(remainingSeconds, locale: locale)
        )
    }

    static func date(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(locale)
        )
    }

    static func time(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(locale)
        )
    }

    static func dateTime(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(locale)
        )
    }

    static func decimal(_ value: Double, maxFractionDigits: Int = 1, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func percent(_ value: Double, maxFractionDigits: Int = 0, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func localizedInteger(_ value: Int, minimumIntegerDigits: Int = 1, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.minimumIntegerDigits = minimumIntegerDigits
        formatter.groupingSeparator = ""
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
