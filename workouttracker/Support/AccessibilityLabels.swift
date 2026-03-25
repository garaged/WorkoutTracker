import Foundation

/// Central location for VoiceOver labels / hints.
///
/// Why this exists:
/// - Accessibility strings tend to drift when they are copied into individual screens.
/// - Keeping them in one place makes it easy to review and keep terminology consistent.
/// - It also gives the app a single place to localize reusable spoken phrasing.
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

        static var settings: String { String(localized: "settings.title") }
        static var settingsHint: String { String(localized: "a11y.button.settings_hint") }

        static var startRest: String { String(localized: "a11y.button.start_rest") }
        static var pauseRest: String { String(localized: "a11y.button.pause_rest") }
        static var finishRest: String { String(localized: "a11y.button.finish_rest") }
        static var resetRest: String { String(localized: "a11y.button.reset_rest") }
        static func restPreset(seconds: Int) -> String {
            String(
                format: String(localized: "a11y.button.set_rest_preset"),
                locale: .autoupdatingCurrent,
                AppFormatting.shortDuration(seconds: seconds)
            )
        }

        static var resumeWorkout: String { String(localized: "Resume") }
        static var resumeWorkoutHint: String { String(localized: "a11y.button.resume_workout_hint") }
        static var finishNow: String { String(localized: "Finish now") }
        static var finishNowHint: String { String(localized: "a11y.button.finish_now_hint") }

        static var copySet: String { String(localized: "a11y.button.set_copy") }
        static var addSet: String { String(localized: "a11y.button.set_add") }
        static var deleteSet: String { String(localized: "a11y.button.set_delete") }
        static var decreaseReps: String { String(localized: "a11y.button.decrease_reps") }
        static var increaseReps: String { String(localized: "a11y.button.increase_reps") }
        static func decreaseWeight(unit: String) -> String {
            String(
                format: String(localized: "a11y.button.decrease_weight"),
                locale: .autoupdatingCurrent,
                unit
            )
        }
        static func increaseWeight(unit: String) -> String {
            String(
                format: String(localized: "a11y.button.increase_weight"),
                locale: .autoupdatingCurrent,
                unit
            )
        }
    }

    enum Hints {
        static var openRoutineEditor: String { String(localized: "a11y.hint.open_routine_editor") }
        static var restTimerToolbar: String { String(localized: "a11y.hint.rest_timer") }
        static func skipSegment(_ title: String) -> String {
            String(
                format: String(localized: "a11y.hint.segment.skip"),
                locale: .autoupdatingCurrent,
                title
            )
        }
    }

    enum Actions {
        static var editRoutine: String { String(localized: "a11y.action.edit_routine") }
    }

    enum Pickers {
        static var progressWindow: String { String(localized: "a11y.picker.progress_window") }
        static var progressWindowHint: String { String(localized: "a11y.picker.progress_window_hint") }
    }

    enum Fields {
        static var reps: String { String(localized: "a11y.field.reps") }
        static func weight(unit: String) -> String {
            String(
                format: String(localized: "a11y.field.weight"),
                locale: .autoupdatingCurrent,
                unit
            )
        }
    }

    enum RestTimer {
        static var title: String { String(localized: "session.rest.title") }
        static var hint: String { String(localized: "a11y.hint.rest_timer") }

        static func value(displaySeconds: Int, isRunning: Bool, hasConfiguredTimer: Bool, totalSeconds: Int) -> String {
            let formatted = AppFormatting.duration(seconds: abs(displaySeconds))

            if displaySeconds < 0 {
                return String(
                    format: String(localized: "a11y.value.rest.overdue"),
                    locale: .autoupdatingCurrent,
                    formatted
                )
            }

            if isRunning {
                return String(
                    format: String(localized: "a11y.value.rest.running"),
                    locale: .autoupdatingCurrent,
                    formatted
                )
            }

            if hasConfiguredTimer {
                let ready = displaySeconds == max(0, totalSeconds)
                if ready {
                    return String(
                        format: String(localized: "a11y.value.rest.ready"),
                        locale: .autoupdatingCurrent,
                        formatted
                    )
                }

                return String(
                    format: String(localized: "a11y.value.rest.paused"),
                    locale: .autoupdatingCurrent,
                    formatted
                )
            }

            return String(localized: "session.rest.ready")
        }
    }

    enum SessionSet {
        static func rowLabel(setNumber: Int) -> String {
            String(
                format: String(localized: "a11y.value.set.number"),
                locale: .autoupdatingCurrent,
                AppFormatting.integer(setNumber)
            )
        }

        static func stateText(currentState: SetState) -> String {
            switch currentState {
            case .current:
                return String(localized: "a11y.value.set.state.current")
            case .pending:
                return String(localized: "a11y.value.set.state.pending")
            case .completed:
                return String(localized: "a11y.value.set.state.completed")
            case .behind:
                return String(localized: "a11y.value.set.state.behind")
            }
        }

        static func rowValue(
            repsText: String,
            weightText: String,
            unit: String,
            targetHint: String?,
            stateText: String?
        ) -> String {
            var parts: [String] = []
            if let stateText, !stateText.isEmpty { parts.append(stateText) }

            if !repsText.isEmpty {
                let repsLabel = NSLocalizedString("Reps", comment: "Accessibility label for reps value")
                parts.append("\(repsLabel): \(repsText)")
            }

            if !weightText.isEmpty {
                let weightLabel = NSLocalizedString("Weight", comment: "Accessibility label for weight value")
                parts.append("\(weightLabel): \(weightText) \(unit)")
            }

            if let targetHint, !targetHint.isEmpty {
                parts.append(targetHint)
            }

            return parts.joined(separator: ". ")
        }

        static func doneToggleLabel(isCompleted: Bool) -> String {
            isCompleted
            ? String(localized: "a11y.button.mark_incomplete")
            : String(localized: "a11y.button.mark_complete")
        }

        static func targetValue(_ target: String) -> String {
            String(
                format: String(localized: "a11y.value.set.target"),
                locale: .autoupdatingCurrent,
                target
            )
        }

        static func visibleBadge(for state: SetState) -> String? {
            switch state {
            case .current:
                return String(localized: "a11y.value.set.state.current")
            case .behind:
                return String(localized: "a11y.value.set.state.behind")
            case .completed:
                return String(localized: "a11y.value.set.state.completed")
            case .pending:
                return nil
            }
        }
    }

    enum Segments {
        static func value(isCurrent: Bool, progressText: String?) -> String {
            var parts: [String] = []
            parts.append(isCurrent ? String(localized: "a11y.value.segment.current") : String(localized: "a11y.value.segment.standard"))
            if let progressText, !progressText.isEmpty {
                parts.append(progressText)
            }
            return parts.joined(separator: ". ")
        }
    }

    enum Home {
        static func cardValue(subtitle: String, badgeTitle: String, needsAttention: Bool) -> String {
            var parts = [badgeTitle, subtitle]
            if needsAttention {
                parts.append(String(localized: "a11y.value.home.needs_attention"))
            }
            return parts.joined(separator: ". ")
        }
    }

    enum SetState {
        case current
        case pending
        case completed
        case behind
    }
}
