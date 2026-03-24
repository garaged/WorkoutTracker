import Foundation

enum ExportNamingFormatter {
    static func backupJSONFilename(
        appVersion: String?,
        build: String?,
        date: Date = Date()
    ) -> String {
        let stamp = filenameTimestamp(date)
        let versionPart = sanitizedFilenameComponent(appVersion, fallback: "0")
        let buildPart = sanitizedFilenameComponent(build, fallback: "0")
        return "workouttracker-backup-\(stamp)-v\(versionPart)-b\(buildPart).json"
    }

    static func supportBundleBaseName(
        appVersion: String?,
        build: String?,
        date: Date = Date()
    ) -> String {
        let stamp = filenameTimestamp(date)
        let versionPart = sanitizedFilenameComponent(appVersion, fallback: "0")
        let buildPart = sanitizedFilenameComponent(build, fallback: "0")
        return "workouttracker-support-bundle-\(stamp)-v\(versionPart)-b\(buildPart)"
    }

    static func supportBundleZipFilename(
        appVersion: String?,
        build: String?,
        date: Date = Date()
    ) -> String {
        supportBundleBaseName(appVersion: appVersion, build: build, date: date) + ".zip"
    }

    static func metadataDisplayTimestamp(
        _ date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func supportSummaryDateLine(
        _ date: Date = Date(),
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        "\(metadataDisplayTimestamp(date, locale: locale, timeZone: timeZone)) (\(iso8601Timestamp(date)))"
    }

    static func iso8601Timestamp(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    static func backupContentsDescription(totalEntities: Int, hasPreferencesSnapshot: Bool) -> String {
        guard totalEntities > 0 else {
            return hasPreferencesSnapshot
                ? String(localized: "backup.export.contents.settings_only")
                : String(localized: "backup.export.contents.no_workouts")
        }

        if hasPreferencesSnapshot {
            let key = totalEntities == 1
                ? "backup.export.contents.settings_and_workouts.singular"
                : "backup.export.contents.settings_and_workouts.plural"
            return AppFormatting.localizedFormat(key, Int64(totalEntities))
        }

        let key = totalEntities == 1
            ? "backup.export.contents.workouts_only.singular"
            : "backup.export.contents.workouts_only.plural"
        return AppFormatting.localizedFormat(key, Int64(totalEntities))
    }

    static func supportBundleDescription() -> String {
        String(localized: "backup.export.support_bundle_ready")
    }

    static func supportBundleNotes(
        logFileIncluded: Bool,
        swiftDataFileCount: Int,
        userDefaultsKeyCount: Int
    ) -> [String] {
        var notes: [String] = []

        if logFileIncluded {
            notes.append(String(localized: "backup.export.note.logs.included"))
        } else {
            notes.append(String(localized: "backup.export.note.logs.missing"))
        }

        if swiftDataFileCount > 0 {
            let key = swiftDataFileCount == 1
                ? "backup.export.note.swiftdata.included.singular"
                : "backup.export.note.swiftdata.included.plural"
            notes.append(AppFormatting.localizedFormat(key, Int64(swiftDataFileCount)))
        } else {
            notes.append(String(localized: "backup.export.note.swiftdata.missing"))
        }

        if userDefaultsKeyCount > 0 {
            let key = userDefaultsKeyCount == 1
                ? "backup.export.note.userdefaults.included.singular"
                : "backup.export.note.userdefaults.included.plural"
            notes.append(AppFormatting.localizedFormat(key, Int64(userDefaultsKeyCount)))
        } else {
            notes.append(String(localized: "backup.export.note.userdefaults.empty"))
        }

        return notes
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()

    private static func filenameTimestamp(_ date: Date) -> String {
        filenameFormatter.string(from: date)
    }

    private static func sanitizedFilenameComponent(_ raw: String?, fallback: String) -> String {
        let trimmed = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return fallback }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        let replacedWhitespace = trimmed.replacingOccurrences(of: " ", with: "-")

        var scalars: [UnicodeScalar] = []
        var previousWasDash = false

        for scalar in replacedWhitespace.unicodeScalars {
            if allowed.contains(scalar) {
                scalars.append(scalar)
                previousWasDash = scalar == "-"
            } else if !previousWasDash {
                scalars.append("-")
                previousWasDash = true
            }
        }

        let candidate = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))

        return candidate.isEmpty ? fallback : candidate
    }
}
