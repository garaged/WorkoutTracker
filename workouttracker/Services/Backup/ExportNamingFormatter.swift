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
                ? "Backup ready. It includes your settings snapshot, but no workout records yet."
                : "Backup ready. No workout records were available to export yet."
        }

        let recordLabel = totalEntities == 1 ? "record" : "records"
        if hasPreferencesSnapshot {
            return "Backup ready. It includes your settings snapshot and \(totalEntities) workout \(recordLabel)."
        }

        return "Backup ready. It includes \(totalEntities) workout \(recordLabel)."
    }

    static func supportBundleDescription() -> String {
        "Support bundle ready. manifest.json will call out any logs or data files that were unavailable at export time."
    }

    static func supportBundleNotes(
        logFileIncluded: Bool,
        swiftDataFileCount: Int,
        userDefaultsKeyCount: Int
    ) -> [String] {
        var notes: [String] = []

        if logFileIncluded {
            notes.append("App log file was included.")
        } else {
            notes.append("No app log file was available at export time.")
        }

        if swiftDataFileCount > 0 {
            let label = swiftDataFileCount == 1 ? "file" : "files"
            notes.append("Included \(swiftDataFileCount) SwiftData store \(label) from Application Support.")
        } else {
            notes.append("No SwiftData store files were found in Application Support.")
        }

        if userDefaultsKeyCount > 0 {
            let label = userDefaultsKeyCount == 1 ? "key" : "keys"
            notes.append("Included a sanitized snapshot of \(userDefaultsKeyCount) UserDefaults \(label).")
        } else {
            notes.append("UserDefaults snapshot was empty at export time.")
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
