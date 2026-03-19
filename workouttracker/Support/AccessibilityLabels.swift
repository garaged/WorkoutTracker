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
        static var verboseLogging: String { String(localized: "a11y.toggle.verbose_logging") }
        static var verboseLoggingHint: String { String(localized: "a11y.toggle.verbose_logging_hint") }
        static var restTimerCue: String { String(localized: "a11y.toggle.rest_timer_cue") }
        static var showOverdue: String { String(localized: "a11y.toggle.show_overdue") }
    }

    enum EmptyStates {
        static var weekProgressTitle: String { String(localized: "a11y.empty_state.week_progress.title") }
        static var weekProgressMessage: String { String(localized: "a11y.empty_state.week_progress.message") }

        static var genericTitle: String { String(localized: "a11y.empty_state.generic.title") }
        static var genericMessage: String { String(localized: "a11y.empty_state.generic.message") }
    }

    enum Buttons {
        static var shareLogs: String { String(localized: "a11y.button.share_logs") }
        static var shareLogsHint: String { String(localized: "a11y.button.share_logs_hint") }

        static var exportBackup: String { String(localized: "a11y.button.export_backup") }
        static var exportBackupHint: String { String(localized: "a11y.button.export_backup_hint") }

        static var copyDiagnostics: String { String(localized: "a11y.button.copy_diagnostics") }
        static var copyDiagnosticsHint: String { String(localized: "a11y.button.copy_diagnostics_hint") }

        static var clearLogs: String { String(localized: "a11y.button.clear_logs") }
        static var clearLogsHint: String { String(localized: "a11y.button.clear_logs_hint") }

        static var scheduleForToday: String { String(localized: "a11y.button.schedule_for_today") }
        static var startNow: String { String(localized: "a11y.button.start_now") }
        static var closeWorkout: String { String(localized: "a11y.button.close_workout") }
        static var createRoutine: String { String(localized: "a11y.button.create_routine") }
        static var scheduleTemplates: String { String(localized: "a11y.button.schedule_templates") }
        static var pauseWorkout: String { String(localized: "a11y.button.pause_workout") }
        static var showPRDetails: String { String(localized: "a11y.button.show_pr_details") }
        static var extendRest15: String { String(localized: "a11y.button.extend_rest_15") }
        static var extendRest30: String { String(localized: "a11y.button.extend_rest_30") }
        static var extendRest60: String { String(localized: "a11y.button.extend_rest_60") }
    }

    enum Hints {
        static var openRoutineEditor: String { String(localized: "a11y.hint.open_routine_editor") }
    }

    enum Actions {
        static var editRoutine: String { String(localized: "a11y.action.edit_routine") }
    }

    enum Pickers {
        static var progressWindow: String { String(localized: "a11y.picker.progress_window") }
        static var progressWindowHint: String { String(localized: "a11y.picker.progress_window_hint") }
    }
}
