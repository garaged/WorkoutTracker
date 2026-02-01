import Foundation

/// Central location for VoiceOver labels / hints.
///
/// Why this exists:
/// - Accessibility strings tend to drift when they're copy/pasted into individual screens.
/// - Keeping them in one place makes it easy to review and keep consistent terminology.
/// - It also gives you a single place to localize later.
///
/// Tip: Keep these short and action-oriented.
enum AccessibilityLabels {
    enum Toggles {
        static let verboseLogging = "Verbose logging"
        static let verboseLoggingHint = "When enabled, the app writes extra debug logs to help troubleshoot issues."
    }


    enum EmptyStates {
        static let weekProgressTitle = "No progress yet"
        static let weekProgressMessage = "Log a session to see trends, streaks, and insights."

        static let genericTitle = "Nothing here yet"
        static let genericMessage = "Add your first item to get started."
    }

    enum Buttons {
        static let shareLogs = "Share logs"
        static let shareLogsHint = "Opens a share sheet with a text file containing recent app logs."

        static let exportBackup = "Export backup"
        static let exportBackupHint = "Creates a backup file you can share or restore later."

        static let copyDiagnostics = "Copy diagnostic info"
        static let copyDiagnosticsHint = "Copies app and device info to the clipboard."

        static let clearLogs = "Clear logs"
        static let clearLogsHint = "Deletes the current log file and starts a new one."
    }

    enum Pickers {
        static let progressWindow = "Progress window"
        static let progressWindowHint = "Changes how many weeks of data are shown."
    }
}
