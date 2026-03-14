// workouttracker/Features/Settings/SettingsScreen.swift
import SwiftUI
import SwiftData

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @StateObject private var prefs = UserPreferences.shared

    private let backupExporter = AppBackupExporter()

    var body: some View {
        List {
            Section(String(localized: "settings.section.backup")) {
                NavigationLink {
                    BackupRestoreScreen()
                        .environment(\.backupExporter, backupExporter)
                } label: {
                    Label(String(localized: "settings.backup.restore"), systemImage: "externaldrive")
                }
            }

            StarterPackSettingsSection()

            // ✅ NEW
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
                .accessibilityIdentifier("settings.weightUnitPicker")

                Picker(String(localized: "settings.units.distance"), selection: $prefs.distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.pickerLabel)
                            .tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.distanceUnitPicker")

                Text(String(localized: "settings.units.help"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Section(String(localized: "settings.section.workout_cues")) {
                Toggle(String(localized: "settings.workout_cues.completion_cue"), isOn: $prefs.restTimerCueEnabled)
                    .accessibilityIdentifier("settings.restTimerCueToggle")
                    .accessibilityLabel(AccessibilityLabels.Toggles.restTimerCue)

                Toggle(String(localized: "settings.workout_cues.haptics"), isOn: $prefs.hapticsEnabled)
                    .accessibilityIdentifier("settings.hapticsToggle")

                Toggle(String(localized: "settings.workout_cues.auto_start_rest"), isOn: $prefs.autoStartRest)
                    .accessibilityIdentifier("settings.autoStartRestToggle")

                Toggle(String(localized: "settings.workout_cues.show_overdue"), isOn: $prefs.restTimerShowOverdue)
                    .accessibilityIdentifier("settings.restTimerShowOverdueToggle")
                    .accessibilityLabel(AccessibilityLabels.Toggles.showOverdue)

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
