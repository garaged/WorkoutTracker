import Foundation

// File: workouttracker/Support/Localization/AppFormatting.swift
//
// Why this file lives here:
// Formatting rules for durations, numbers, and dates are shared support logic.
// Keeping them out of views makes locale behavior consistent and easier to test.

enum AppFormatting {
    private static let bundleCacheLock = NSLock()
    private static var localizedBundleCache: [String: Bundle] = [:]

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
                    format: localizedString("format.duration.short.hours_minutes", locale: locale),
                    locale: locale,
                    localizedInteger(hours, locale: locale),
                    localizedInteger(minutes, locale: locale)
                )
            }

            return sign + String(
                format: localizedString("format.duration.short.hours_minutes_seconds", locale: locale),
                locale: locale,
                localizedInteger(hours, locale: locale),
                localizedInteger(minutes, locale: locale),
                localizedInteger(remainingSeconds, locale: locale)
            )
        }

        if absoluteSeconds < 60 {
            return sign + String(
                format: localizedString("format.duration.short.seconds", locale: locale),
                locale: locale,
                localizedInteger(absoluteSeconds, locale: locale)
            )
        }

        if remainingSeconds == 0 {
            return sign + String(
                format: localizedString("format.duration.short.minutes", locale: locale),
                locale: locale,
                localizedInteger(minutes, locale: locale)
            )
        }

        return sign + String(
            format: localizedString("format.duration.short.minutes_seconds", locale: locale),
            locale: locale,
            localizedInteger(minutes, locale: locale),
            localizedInteger(remainingSeconds, locale: locale)
        )
    }

    static func date(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        dateFormatter(locale: locale, dateStyle: .medium, timeStyle: .none).string(from: date)
    }

    static func monthDay(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        dateFormatter(
            locale: locale,
            dateStyle: .none,
            timeStyle: .none,
            localizedTemplate: "MMM d"
        ).string(from: date)
    }

    static func dateRange(start: Date, end: Date, locale: Locale = .autoupdatingCurrent) -> String {
        "\(monthDay(start, locale: locale)) – \(monthDay(end, locale: locale))"
    }

    static func time(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        dateFormatter(locale: locale, dateStyle: .none, timeStyle: .short).string(from: date)
    }

    static func dateTime(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        dateFormatter(locale: locale, dateStyle: .medium, timeStyle: .short).string(from: date)
    }

    static func decimal(_ value: Double, maxFractionDigits: Int = 1, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = numberFormatter(
            locale: locale,
            numberStyle: .decimal,
            minimumFractionDigits: 0,
            maximumFractionDigits: maxFractionDigits
        )
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func percent(_ value: Double, maxFractionDigits: Int = 0, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = numberFormatter(
            locale: locale,
            numberStyle: .percent,
            minimumFractionDigits: 0,
            maximumFractionDigits: maxFractionDigits
        )
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func integer(_ value: Int, locale: Locale = .autoupdatingCurrent) -> String {
        localizedInteger(value, locale: locale)
    }



    static func exerciseCatalogNameKey(for catalogKey: String) -> String {
        let token = catalogKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .map { character in
                if character.isLetter || character.isNumber {
                    return String(character)
                }
                return "_"
            }
            .joined()

        return "exercise.catalog.\(token).name"
    }

    static func localized(_ key: String, locale: Locale = .autoupdatingCurrent) -> String {
        localizedString(key, locale: locale)
    }

    static func localizedFormat(_ key: String, locale: Locale = .autoupdatingCurrent, _ arguments: CVarArg...) -> String {
        String(format: localizedString(key, locale: locale), locale: locale, arguments: arguments)
    }


    private static func localizedString(_ key: String, locale: Locale) -> String {
        let bundle = localizedBundle(for: locale)
        let localized = bundle.localizedString(forKey: key, value: nil, table: nil)

        if localized != key {
            return localized
        }

        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        let cacheKey = locale.identifier
        bundleCacheLock.lock()
        if let cachedBundle = localizedBundleCache[cacheKey] {
            bundleCacheLock.unlock()
            return cachedBundle
        }
        bundleCacheLock.unlock()

        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let languageCode = locale.language.languageCode?.identifier ?? locale.language.languageCode?.identifier ?? ""
        let candidates = [identifier, locale.identifier, languageCode].filter { !$0.isEmpty }

        let preferred = Bundle.preferredLocalizations(from: candidates)
        for localization in preferred + candidates {
            if let path = Bundle.main.path(forResource: localization, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                bundleCacheLock.lock()
                localizedBundleCache[cacheKey] = bundle
                bundleCacheLock.unlock()
                return bundle
            }
        }

        bundleCacheLock.lock()
        localizedBundleCache[cacheKey] = .main
        bundleCacheLock.unlock()
        return .main
    }

    private static func localizedInteger(_ value: Int, minimumIntegerDigits: Int = 1, locale: Locale) -> String {
        let formatter = numberFormatter(
            locale: locale,
            numberStyle: .decimal,
            minimumFractionDigits: 0,
            maximumFractionDigits: 0,
            minimumIntegerDigits: minimumIntegerDigits,
            usesGroupingSeparator: false
        )
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func numberFormatter(
        locale: Locale,
        numberStyle: NumberFormatter.Style,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int,
        minimumIntegerDigits: Int = 1,
        usesGroupingSeparator: Bool = true
    ) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = numberStyle
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumIntegerDigits = minimumIntegerDigits
        formatter.usesGroupingSeparator = usesGroupingSeparator
        if !usesGroupingSeparator {
            formatter.groupingSeparator = ""
        }
        return formatter
    }

    private static func dateFormatter(
        locale: Locale,
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style,
        localizedTemplate: String? = nil
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        if let localizedTemplate {
            formatter.setLocalizedDateFormatFromTemplate(localizedTemplate)
        }
        return formatter
    }
}
