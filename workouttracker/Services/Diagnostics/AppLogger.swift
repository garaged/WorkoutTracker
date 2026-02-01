import Foundation
import os

/// A lightweight, app-owned logging wrapper.
///
/// Why this exists (vs using `print()` everywhere):
/// - `os.Logger` gives you structured logging in Console, with categories and levels.
/// - In the real world you can't reliably *read* the system log from your app,
///   so we also mirror messages to an app-owned text file that you can export.
/// - Centralizing categories prevents a random string explosion over time.
final class AppLogger {
    private static let verboseLoggingDefaultsKey = "prefs.diagnosticsVerboseLoggingEnabled"

    enum Category: String, CaseIterable {
        case templates
        case sessions
        case persistence
        case diagnostics
    }

    enum Level {
        case debug
        case info
        case notice
        case warning
        case error
        case fault
    }

    static let shared = AppLogger()

    private let subsystem: String
    private let store: LogStore

    init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "workouttracker",
        store: LogStore = LogStore()
    ) {
        self.subsystem = subsystem
        self.store = store

        // Ensure the file exists early so ShareSheet doesn't race file creation.
        Task { await store.ensureFileExists() }
    }

    // MARK: - Public API

    func debug(_ message: String, category: Category, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message: message, file: file, function: function, line: line)
    }

    func info(_ message: String, category: Category, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.info, category: category, message: message, file: file, function: function, line: line)
    }

    func notice(_ message: String, category: Category, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.notice, category: category, message: message, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: Category, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message: message, file: file, function: function, line: line)
    }

    func error(_ message: String, category: Category, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.error, category: category, message: message, file: file, function: function, line: line)
    }

    func fault(_ message: String, category: Category, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.fault, category: category, message: message, file: file, function: function, line: line)
    }

    /// Location of the app-owned log file, suitable for sharing.
    func logFileURL() -> URL { store.logFileURL }

    /// Deletes the current log file and starts fresh.
    func clearLogs() {
        Task { await store.clear() }
    }

    // MARK: - Internals

    private func isVerboseEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: Self.verboseLoggingDefaultsKey)
    }

    private func log(_ level: Level, category: Category, message: String, file: String, function: String, line: Int) {
        if level == .debug && !isVerboseEnabled() {
            return
        }
        let logger = Logger(subsystem: subsystem, category: category.rawValue)

        // This string is “public” by intent: it's going to a shareable file.
        // Avoid logging secrets / tokens here.
        let stamp = ISO8601DateFormatter().string(from: Date())
        let location = "\(file):\(line) \(function)"
        let formatted = "[\(stamp)] [\(category.rawValue)] [\(levelLabel(level))] \(message) — \(location)"

        // Mirror to the system log for Console.app.
        // Use `logger.log(level:)` for broad compatibility across iOS versions.
        let t: OSLogType
        switch level {
        case .debug:
            t = .debug
        case .info:
            t = .info
        case .notice, .warning:
            t = .default
        case .error:
            t = .error
        case .fault:
            t = .fault
        }
        logger.log(level: t, "\(formatted, privacy: .public)")

        // Mirror to our file for export.
        Task { await store.appendLine(LogRedactor.redact(formatted)) }
    }

    private func levelLabel(_ level: Level) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .fault: return "FAULT"
        }
    }
}

// MARK: - LogStore

/// Actor that owns file IO, keeping logging safe under Swift concurrency.
actor LogStore {
    nonisolated let logFileURL: URL

    private let maxBytes: Int

    init(maxBytes: Int = 1_000_000) {
        self.maxBytes = maxBytes

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        let dir = base.appendingPathComponent("Diagnostics", isDirectory: true)
        self.logFileURL = dir.appendingPathComponent("workouttracker.log")

        // Best effort directory creation.
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func ensureFileExists() {
        guard !FileManager.default.fileExists(atPath: logFileURL.path) else { return }
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    }

    func appendLine(_ line: String) {
        ensureFileExists()
        rotateIfNeeded()

        let data = (line + "\n").data(using: .utf8) ?? Data()
        do {
            let handle = try FileHandle(forWritingTo: logFileURL)
            try handle.seekToEnd()
            handle.write(data)
            try handle.close()
        } catch {
            // If logging fails, we intentionally do nothing.
            // (We don't want logging to crash the app.)
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: logFileURL)
        ensureFileExists()
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let size = attrs[.size] as? NSNumber else {
            return
        }

        guard size.intValue > maxBytes else { return }

        let old = logFileURL.deletingLastPathComponent().appendingPathComponent("workouttracker.old.log")
        try? FileManager.default.removeItem(at: old)
        try? FileManager.default.moveItem(at: logFileURL, to: old)
        ensureFileExists()
    }
}
