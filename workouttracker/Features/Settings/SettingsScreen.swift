import SwiftUI
import SwiftData

// File: workouttracker/Features/Settings/SettingsScreen.swift
//
// Patch:
// - Adds accessibilityIdentifier for the Verbose Logging toggle so UITests can find it reliably.

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @StateObject private var prefs = UserPreferences.shared

    private let backupExporter = AppBackupExporter()

    var body: some View {
        List {
            Section("Preferences") {
                NavigationLink {
                    PreferencesScreen()
                } label: {
                    Label("Preferences", systemImage: "slider.horizontal.3")
                }
            }

            Section("Backup") {
                NavigationLink {
                    BackupRestoreScreen()
                        .environment(\.backupExporter, backupExporter)
                } label: {
                    Label("Backup & Restore", systemImage: "externaldrive")
                }
            }

            StarterPackSettingsSection()


            Section("Diagnostics") {
                NavigationLink {
                    FeedbackScreen()
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
        }
        .navigationTitle("Settings")
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
