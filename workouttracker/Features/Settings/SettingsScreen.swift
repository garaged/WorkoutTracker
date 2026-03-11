// workouttracker/Features/Settings/SettingsScreen.swift
import SwiftUI
import SwiftData

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @StateObject private var prefs = UserPreferences.shared

    private let backupExporter = AppBackupExporter()

    var body: some View {
        List {
            Section("Backup") {
                NavigationLink {
                    BackupRestoreScreen()
                        .environment(\.backupExporter, backupExporter)
                } label: {
                    Label("Backup & Restore", systemImage: "externaldrive")
                }
            }

            StarterPackSettingsSection()

            // ✅ NEW
            Section("Programs") {
                NavigationLink {
                    ProgramsLibraryScreen()
                } label: {
                    Label("Programs", systemImage: "books.vertical")
                }
                .accessibilityIdentifier("settings.programsLink")
                
                NavigationLink {
                    ProgramAssetsScreen()
                } label: {
                    Label("Program Assets", systemImage: "wrench.and.screwdriver")
                }
                .accessibilityIdentifier("settings.programAssetsLink")
            }

            Section("Units") {
                Picker("Weight unit", selection: $prefs.weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.pickerLabel)
                            .tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.weightUnitPicker")

                Picker("Distance unit", selection: $prefs.distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.pickerLabel)
                            .tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.distanceUnitPicker")

                Text("Weight is converted for display and entry using your selected unit. Cardio distance is stored internally in kilometers and converted in routine planning and workout logging when needed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Section("Workout cues") {
                Toggle("Rest sound cues", isOn: $prefs.restSoundCuesEnabled)
                    .accessibilityIdentifier("settings.restSoundCuesToggle")

                Toggle("Haptics", isOn: $prefs.hapticsEnabled)
                    .accessibilityIdentifier("settings.hapticsToggle")

                Toggle("Auto-start rest timer", isOn: $prefs.autoStartRest)
                    .accessibilityIdentifier("settings.autoStartRestToggle")

                Text("Rest sound cues play at rest start, at 3, 2, and 1 seconds remaining, and again when rest finishes. They obey silent mode and should not interrupt music.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                NavigationLink {
                    FeedbackScreen()
                } label: {
                    Label("Feedback", systemImage: "ladybug")
                }

                HStack {
                    Text("Verbose logging")
                    Spacer()
                    Toggle("", isOn: $prefs.diagnosticsVerboseLoggingEnabled)
                        .labelsHidden()
                        .accessibilityIdentifier("settings.verboseLoggingToggle")
                }
                .accessibilityLabel(AccessibilityLabels.Toggles.verboseLogging)
                .accessibilityHint(AccessibilityLabels.Toggles.verboseLoggingHint)
            }
            
            ExerciseIllustrationSetPickerSection()
            
            Section("Support") {
                NavigationLink {
                    SupportTipJarView()
                } label: {
                    Label("Tip Jar", systemImage: "heart")
                }
                .accessibilityIdentifier("settings.tipJarLink")
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersionLabel)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Last backup")
                    Spacer()
                    Text(lastBackupLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .readableWidth()
        .navigationTitle("Settings")
        .scrollDismissesKeyboard(.interactively)
    }

    private var appVersionLabel: String {
        let info = Bundle.main.infoDictionary
        let v = (info?["CFBundleShortVersionString"] as? String) ?? "0"
        let b = (info?["CFBundleVersion"] as? String) ?? "0"
        return "\(v) (\(b))"
    }

    private var lastBackupLabel: String {
        guard let d = prefs.lastBackupAt else { return "Never" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }
}
