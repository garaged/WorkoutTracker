// workouttracker/Features/Settings/SettingsScreen.swift
import SwiftUI

struct SettingsScreen: View {
    @StateObject private var prefs = UserPreferences.shared

    // Create once per screen instance so both destinations share the same exporter.
    private let exporter = AppBackupExporter()

    var body: some View {
        Form {
            Section("Units") {
                if weightUnits.count == 2 {
                    Picker("Weight", selection: $prefs.weightUnit) {
                        ForEach(weightUnits, id: \.self) { u in
                            Text(label(for: u)).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    Picker("Weight", selection: $prefs.weightUnit) {
                        ForEach(weightUnits, id: \.self) { u in
                            Text(label(for: u)).tag(u)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("Defaults") {
                Stepper(value: $prefs.defaultRestSeconds, in: 0...900, step: 5) {
                    HStack {
                        Text("Default rest")
                        Spacer()
                        Text(prefs.defaultRestLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Haptics", isOn: $prefs.hapticsEnabled)
                Toggle("Auto-start rest timer", isOn: $prefs.autoStartRest)
                Toggle("Confirm destructive actions", isOn: $prefs.confirmDestructiveActions)
            }

            Section("Backup") {
                NavigationLink {
                    BackupRestoreScreen()
                        .environment(\.backupExporter, exporter)
                } label: {
                    Label("Backup & Restore", systemImage: "externaldrive")
                }
            }

            Section("Diagnostics") {
    NavigationLink {
        FeedbackScreen()
            .environment(\.backupExporter, exporter)
    } label: {
        Label("Feedback", systemImage: "ladybug")
    }

    Toggle("Verbose logging", isOn: $prefs.diagnosticsVerboseLoggingEnabled)
        .accessibilityIdentifier("settings.verboseLoggingToggle")
        .accessibilityLabel(AccessibilityLabels.Toggles.verboseLogging)
        .accessibilityHint(AccessibilityLabels.Toggles.verboseLoggingHint)
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

            Section {
                Button(role: .destructive) {
                    prefs.resetToDefaults()
                } label: {
                    Text("Reset Settings to Defaults")
                }
            } footer: {
                Text("Settings are stored locally via UserDefaults. Workout data lives in SwiftData; use Backup to export JSON.")
            }
        }
        .navigationTitle("Settings")
    }

    private var weightUnits: [WeightUnit] {
        Array(WeightUnit.allCases)
    }

    private func label(for unit: WeightUnit) -> String {
        let s = String(describing: unit)
        if s.lowercased().contains("kg") { return "Kilograms (kg)" }
        if s.lowercased().contains("lb") { return "Pounds (lb)" }
        return s
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
