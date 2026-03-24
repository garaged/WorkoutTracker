import Foundation

/// Exports a shareable "support bundle" ZIP, designed for debugging real-world issues.
///
/// This is intentionally separate from the JSON backup you already use for validated restores.
///
/// Bundle contents (inside the ZIP):
/// - manifest.json: metadata (app version/build/timestamp/timezone)
/// - logs/workouttracker.log: app-owned log file (if present)
/// - settings/userdefaults.json: best-effort snapshot of UserDefaults (sanitized)
/// - data/: best-effort snapshot of SwiftData store files (.sqlite + wal/shm)
final class AppBackupExporter: BackupExporting {

    init() {}

    func exportBackup() throws -> URL {
        let info = Bundle.main.infoDictionary
        let appV = (info?["CFBundleShortVersionString"] as? String) ?? "0"
        let build = (info?["CFBundleVersion"] as? String) ?? "0"
        let exportDate = Date()

        let baseName = ExportNamingFormatter.supportBundleBaseName(
            appVersion: appV,
            build: build,
            date: exportDate
        )
        let fm = FileManager.default

        // Build bundle folder in temp.
        let bundleDir = fm.temporaryDirectory.appendingPathComponent(baseName, isDirectory: true)
        let logsDir = bundleDir.appendingPathComponent("logs", isDirectory: true)
        let settingsDir = bundleDir.appendingPathComponent("settings", isDirectory: true)
        let dataDir = bundleDir.appendingPathComponent("data", isDirectory: true)

        try fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: settingsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

        // 1) Logs (if available)
        let logFileIncluded = Self.copyLogFile(into: logsDir)

        // 2) UserDefaults snapshot (sanitized + JSON-safe)
        let defaultsSnapshot = Self.userDefaultsSnapshot()
        let defaultsURL = settingsDir.appendingPathComponent("userdefaults.json")
        try Self.writeJSON(defaultsSnapshot, to: defaultsURL)

        // 3) SwiftData store snapshot (best-effort for diagnostics)
        let swiftDataFileCount = Self.copySwiftDataStoreFiles(into: dataDir)

        // 4) Manifest
        let manifestURL = bundleDir.appendingPathComponent("manifest.json")
        let manifest: [String: Any] = [
            "appVersion": appV,
            "appBuild": build,
            "createdAt": ExportNamingFormatter.iso8601Timestamp(exportDate),
            "createdAtDisplay": ExportNamingFormatter.metadataDisplayTimestamp(exportDate),
            "timeZone": TimeZone.current.identifier,
            "logFileIncluded": logFileIncluded,
            "userDefaultsKeyCount": defaultsSnapshot.count,
            "swiftDataFileCount": swiftDataFileCount,
            "notes": ExportNamingFormatter.supportBundleNotes(
                logFileIncluded: logFileIncluded,
                swiftDataFileCount: swiftDataFileCount,
                userDefaultsKeyCount: defaultsSnapshot.count
            )
        ]
        try Self.writeJSON(manifest, to: manifestURL)

        // Zip
        let zipFilename = ExportNamingFormatter.supportBundleZipFilename(
            appVersion: appV,
            build: build,
            date: exportDate
        )
        let zipURL = fm.temporaryDirectory.appendingPathComponent(zipFilename)
        _ = try? fm.removeItem(at: zipURL)
        try ZipArchiver.zipDirectory(at: bundleDir, to: zipURL, keepParent: true)

        // Clean up working folder (zip is the deliverable).
        _ = try? fm.removeItem(at: bundleDir)

        // Update "Last backup" safely under Swift 6 concurrency.
        // UserPreferences is @MainActor, so we hop to main without blocking export.
        Task { @MainActor in
            UserPreferences.shared.lastBackupAt = exportDate
        }

        return zipURL
    }

    // MARK: - Helpers

    private static func writeJSON(_ obj: Any, to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: [.atomic])
    }

    private static func copyLogFile(into logsDir: URL) -> Bool {
        let fm = FileManager.default

        // Use the app-owned log file managed by AppLogger, so the exporter stays in sync
        // even if the log location changes later.
        let logURL = AppLogger.shared.logFileURL()
        guard fm.fileExists(atPath: logURL.path) else { return false }

        let dest = logsDir.appendingPathComponent(logURL.lastPathComponent)
        _ = try? fm.removeItem(at: dest)

        do {
            try fm.copyItem(at: logURL, to: dest)
            return true
        } catch {
            return false
        }
    }

    /// Produces a JSON-safe (and lightly sanitized) snapshot of UserDefaults.
    private static func userDefaultsSnapshot() -> [String: Any] {
        let raw = UserDefaults.standard.dictionaryRepresentation()

        // Light redaction: avoid exporting likely secret-ish keys.
        let redactTokens = ["token", "secret", "password", "apikey", "api_key", "auth", "authorization"]

        var out: [String: Any] = [:]
        out.reserveCapacity(raw.count)

        for (k, v) in raw {
            let lower = k.lowercased()
            if redactTokens.contains(where: { lower.contains($0) }) {
                out[k] = "<redacted>"
                continue
            }
            out[k] = jsonSafe(v)
        }

        return out
    }

    private static func jsonSafe(_ value: Any) -> Any {
        switch value {
        case let v as String: return v
        case let v as NSNumber: return v
        case let v as Bool: return v
        case let v as Int: return v
        case let v as Double: return v
        case let v as Float: return v
        case let v as Date:
            return ExportNamingFormatter.iso8601Timestamp(v)
        case let v as Data:
            return ["type": "data", "base64": v.base64EncodedString()]
        case let v as [Any]:
            return v.map { jsonSafe($0) }
        case let v as [String: Any]:
            var m: [String: Any] = [:]
            for (k, vv) in v { m[k] = jsonSafe(vv) }
            return m
        default:
            return String(describing: value)
        }
    }

    /// Copies likely SwiftData persistent store files from Application Support into `dataDir`.
    /// Returns the number of files copied. This is best-effort for diagnostics (not yet a
    /// "restore" mechanism).
    private static func copySwiftDataStoreFiles(into dataDir: URL) -> Int {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return 0 }

        // Common SQLite/WAL/SHM suffixes.
        let suffixes = [".sqlite", ".sqlite-wal", ".sqlite-shm", "-wal", "-shm"]

        var copiedCount = 0
        let enumerator = fm.enumerator(at: appSupport, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        while let fileURL = enumerator?.nextObject() as? URL {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            let name = fileURL.lastPathComponent.lowercased()
            guard suffixes.contains(where: { name.hasSuffix($0) }) else { continue }

            // Flatten relative path to keep zip readable.
            let rel = fileURL.path.replacingOccurrences(of: appSupport.path, with: "")
            let safeRel = rel.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .replacingOccurrences(of: "/", with: "__")

            let dest = dataDir.appendingPathComponent(safeRel)
            _ = try? fm.removeItem(at: dest)

            do {
                try fm.copyItem(at: fileURL, to: dest)
                copiedCount += 1
            } catch {
                continue
            }
        }

        return copiedCount
    }
}
