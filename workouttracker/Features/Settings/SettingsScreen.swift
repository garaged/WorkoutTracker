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
