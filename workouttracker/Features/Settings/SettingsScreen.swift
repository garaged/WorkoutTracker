// workouttracker/Features/Settings/SettingsScreen.swift
import SwiftUI
import SwiftData

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @StateObject private var prefs = UserPreferences.shared
    @ObservedObject private var experienceStore = ExperiencePreferenceStore.shared

    @Query private var workoutSessions: [WorkoutSession]
    @Query private var trackedActivitySessions: [TrackedActivitySession]

    @AppStorage(TrackedActivityHealthPreferences.autoSaveCompletedActivitiesKey)
    private var autoSaveToAppleHealth = false

    private let backupExporter = AppBackupExporter()

    var body: some View {
        List {
            Section(String(localized: "settings.experience.section", defaultValue: "App experience")) {
                Text(String(localized: "settings.experience.help", defaultValue: "Choose the level of detail that feels right for you. Your workout history stays the same."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                experienceOption(
                    .easy,
                    title: String(localized: "settings.experience.easy", defaultValue: "Easy mode"),
                    detail: String(localized: "settings.experience.easy.detail", defaultValue: "Simple starts and a focused workout flow.")
                )

                experienceOption(
                    .pro,
                    title: String(localized: "settings.experience.pro", defaultValue: "Pro mode"),
                    detail: String(localized: "settings.experience.pro.detail", defaultValue: "The full dashboard and advanced workout tools.")
                )

                if experienceStore.state.requested != nil {
                    Text(String(localized: "settings.experience.pending", defaultValue: "Your choice will apply after the active workout is finished."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("Settings.Experience.Pending")
                }
            }

            Section(String(localized: "settings.section.backup")) {
                NavigationLink {
                    BackupRestoreScreen()
                        .environment(\.backupExporter, backupExporter)
                } label: {
                    Label(String(localized: "settings.backup.restore"), systemImage: "externaldrive")
                }
            }

            Section(String(localized: "settings.health.section", defaultValue: "Health")) {
                Toggle(String(localized: "settings.health.auto_save", defaultValue: "Auto-save completed tracked activities to Apple Health"), isOn: $autoSaveToAppleHealth)
                    .accessibilityIdentifier("settings.healthAutoSaveToggle")

                NavigationLink {
                    HealthPermissionsView()
                } label: {
                    Label(String(localized: "activities.health.title", defaultValue: "Apple Health"), systemImage: "heart.text.square")
                }
                .accessibilityIdentifier("settings.healthPermissionsLink")

                Text(String(localized: "settings.health.auto_save.help", defaultValue: "When this is on, completed tracked activities try to save automatically to Apple Health. Manual retry stays available if a save attempt fails, and later edits remain local in WorkoutTracker."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            StarterPackSettingsSection()

            Section(String(localized: "settings.section.programs")) {
                NavigationLink {
                    ProgramsLibraryScreen()
                } label: {
                    Label(String(localized: "settings.programs.library"), systemImage: "books.vertical")
                }
                .accessibilityIdentifier("settings.programsLink")

                NavigationLink {
                    ProgramAssetsScreen()
                } label: {
                    Label(String(localized: "settings.programs.assets"), systemImage: "wrench.and.screwdriver")
                }
                .accessibilityIdentifier("settings.programAssetsLink")
            }

            Section(String(localized: "settings.section.units")) {
                Picker(String(localized: "settings.units.weight"), selection: $prefs.weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.pickerLabel)
                            .tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel(Text(verbatim: String(localized: "settings.units.weight")))
                .accessibilityHint(Text(verbatim: String(localized: "settings.units.help")))
                .accessibilityIdentifier("settings.weightUnitPicker")

                Picker(String(localized: "settings.units.distance"), selection: $prefs.distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.pickerLabel)
                            .tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel(Text(verbatim: String(localized: "settings.units.distance")))
                .accessibilityHint(Text(verbatim: String(localized: "settings.units.help")))
                .accessibilityIdentifier("settings.distanceUnitPicker")

                Text(String(localized: "settings.units.help"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.section.workout_cues")) {
                Toggle(String(localized: "settings.workout_cues.completion_cue"), isOn: $prefs.restTimerCueEnabled)
                    .accessibilityIdentifier("settings.restTimerCueToggle")
                    .accessibilityLabel(AccessibilityLabels.Toggles.restTimerCue)
                    .accessibilityHint(Text(verbatim: String(localized: "settings.workout_cues.help")))

                Toggle(String(localized: "settings.workout_cues.haptics"), isOn: $prefs.hapticsEnabled)
                    .accessibilityLabel(Text(verbatim: String(localized: "settings.workout_cues.haptics")))
                    .accessibilityHint(Text(verbatim: String(localized: "settings.workout_cues.help")))
                    .accessibilityIdentifier("settings.hapticsToggle")

                Toggle(String(localized: "settings.workout_cues.auto_start_rest"), isOn: $prefs.autoStartRest)
                    .accessibilityLabel(Text(verbatim: String(localized: "settings.workout_cues.auto_start_rest")))
                    .accessibilityHint(Text(verbatim: String(localized: "settings.workout_cues.help")))
                    .accessibilityIdentifier("settings.autoStartRestToggle")

                Toggle(String(localized: "settings.workout_cues.show_overdue"), isOn: $prefs.restTimerShowOverdue)
                    .accessibilityIdentifier("settings.restTimerShowOverdueToggle")
                    .accessibilityLabel(AccessibilityLabels.Toggles.showOverdue)
                    .accessibilityHint(Text(verbatim: String(localized: "settings.workout_cues.help")))

                Text(String(localized: "settings.workout_cues.help"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.section.diagnostics")) {
                NavigationLink {
                    FeedbackScreen()
                } label: {
                    Label(String(localized: "settings.feedback"), systemImage: "ladybug")
                }

                HStack {
                    Text(String(localized: "settings.verbose_logging"))
                    Spacer()
                    Toggle("", isOn: $prefs.diagnosticsVerboseLoggingEnabled)
                        .labelsHidden()
                        .accessibilityIdentifier("settings.verboseLoggingToggle")
                }
                .accessibilityLabel(AccessibilityLabels.Toggles.verboseLogging)
                .accessibilityHint(AccessibilityLabels.Toggles.verboseLoggingHint)
            }

            ExerciseIllustrationSetPickerSection()

            Section(String(localized: "settings.section.support")) {
                NavigationLink {
                    SupportTipJarView()
                } label: {
                    Label(String(localized: "settings.tip_jar"), systemImage: "heart")
                }
                .accessibilityIdentifier("settings.tipJarLink")
            }

            Section(String(localized: "settings.section.about")) {
                HStack {
                    Text(String(localized: "settings.about.version"))
                    Spacer()
                    Text(appVersionLabel)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(String(localized: "settings.about.last_backup"))
                    Spacer()
                    Text(lastBackupLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .readableWidth()
        .navigationTitle(String(localized: "settings.title"))
        .scrollDismissesKeyboard(.interactively)
    }

    private var hasActiveSession: Bool {
        workoutSessions.contains(where: \.isUnfinished)
            || trackedActivitySessions.contains(where: \.isActive)
    }

    private func experienceOption(
        _ mode: ExperiencePreferenceState.Mode,
        title: String,
        detail: String
    ) -> some View {
        let isSelected = experienceStore.state.effective == mode

        return Button {
            experienceStore.request(mode, hasActiveSession: hasActiveSession)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Settings.Experience.\(mode == .easy ? "Easy" : "Pro")")
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? String(localized: "settings.experience.selected", defaultValue: "Selected") : String(localized: "settings.experience.not_selected", defaultValue: "Not selected"))
        .accessibilityHint(hasActiveSession ? String(localized: "settings.experience.deferred_hint", defaultValue: "This change will apply after the active workout is finished.") : String(localized: "settings.experience.immediate_hint", defaultValue: "Changes the app experience immediately."))
    }

    private var appVersionLabel: String {
        let info = Bundle.main.infoDictionary
        let v = (info?["CFBundleShortVersionString"] as? String) ?? "0"
        let b = (info?["CFBundleVersion"] as? String) ?? "0"
        return "\(v) (\(b))"
    }

    private var lastBackupLabel: String {
        guard let d = prefs.lastBackupAt else { return String(localized: "settings.about.never") }
        return AppFormatting.dateTime(d)
    }
}
