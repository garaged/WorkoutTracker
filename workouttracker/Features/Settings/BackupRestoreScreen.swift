// workouttracker/Features/Settings/BackupRestoreScreen.swift
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupRestoreScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.backupExporter) private var backupExporter

    private let backupService = BackupService()
    @StateObject private var prefs = UserPreferences.shared

    // JSON backup (restore-friendly)
    @State private var exportURL: URL?
    @State private var exportError: String?

    // Full diagnostic backup (ZIP) via AppBackupExporter
    @State private var fullExportURL: URL?
    @State private var fullExportError: String?

    @State private var showImporter = false
    @State private var importedData: Data?
    @State private var importedValidation: BackupService.Validation?
    @State private var importError: String?
    @State private var restoreError: String?
    @State private var restoreSuccess: String?

    var body: some View {
        Form {
            Section("Export") {
                // Opinionated: keep JSON because it's the safest path for restore (you already validate it).
                // Add ZIP for real-world debugging (logs + settings + best-effort SwiftData store).
                Button {
                    exportBackupJSON()
                } label: {
                    Label("Generate JSON Backup", systemImage: "square.and.arrow.up")
                }

                if let url = exportURL {
                    ShareLink(item: url) {
                        Label("Share JSON Backup", systemImage: "square.and.arrow.up.on.square")
                    }
                    .padding(.top, 4)

                    Text(url.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let exportError {
                    Text(exportError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Divider().padding(.vertical, 6)

                Button {
                    exportFullBackupZIP()
                } label: {
                    Label("Generate Full Backup (ZIP)", systemImage: "ladybug")
                }
                .disabled(backupExporter == nil)
                .accessibilityLabel(AccessibilityLabels.Buttons.exportBackup)
                .accessibilityHint(AccessibilityLabels.Buttons.exportBackupHint)

                if let url = fullExportURL {
                    ShareLink(item: url) {
                        Label("Share Full Backup", systemImage: "square.and.arrow.up.on.square")
                    }
                    .padding(.top, 4)

                    Text(url.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if backupExporter == nil {
                    Text("Full backup export isn’t configured yet. Add an exporter in SettingsScreen via .environment(\\.backupExporter, AppBackupExporter()).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                if let fullExportError {
                    Text(fullExportError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Text("JSON is best for restore. ZIP is best for debugging (logs + settings + data snapshot).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Section("Import") {
                Button {
                    showImporter = true
                } label: {
                    Label("Select JSON Backup File", systemImage: "square.and.arrow.down")
                }

                if let v = importedValidation {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Backup found")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Schema v\(v.schemaVersion)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let appV = v.appVersion {
                            if let b = v.appBuild {
                                Text("App: \(appV) (\(b))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("App: \(appV)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let dev = v.deviceName {
                            let os = v.systemVersion ?? "—"
                            Text("Device: \(dev) • iOS \(os)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Text("Created: \(v.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Preferences snapshot: \(v.hasPreferencesSnapshot ? "Yes" : "No")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 6)

                        ForEach(v.entityCountsByType, id: \.type) { row in
                            HStack {
                                Text(row.type)
                                Spacer()
                                Text("\(row.count)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.footnote)
                        }

                        HStack {
                            Text("Total")
                            Spacer()
                            Text("\(v.totalEntities)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                        .fontWeight(.semibold)
                    }
                    .padding(.top, 6)
                }

                if let importError {
                    Text(importError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section("Restore") {
                Button {
                    restoreSettingsOnly()
                } label: {
                    Label("Restore Settings From Backup", systemImage: "gearshape.arrow.triangle.2.circlepath")
                }
                .disabled(importedData == nil)

                Button(role: .destructive) {
                    attemptWorkoutRestore()
                } label: {
                    Label("Restore Workout Data (Not Enabled)", systemImage: "externaldrive.badge.plus")
                }
                .disabled(true)

                if let restoreSuccess {
                    Text(restoreSuccess)
                        .foregroundStyle(.green)
                        .font(.footnote)
                }

                if let restoreError {
                    Text(restoreError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Text("Settings restore is safe. Workout-data restore will be enabled only after per-model import mapping exists.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Backup & Restore")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                let url = try result.get().first!
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }

                let data = try Data(contentsOf: url)
                importedData = data
                importedValidation = try backupService.validate(data)
                importError = nil
                restoreError = nil
                restoreSuccess = nil
            } catch {
                importedData = nil
                importedValidation = nil
                importError = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Actions

    private func exportBackupJSON() {
        do {
            let data = try backupService.exportJSON(
                context: context,
                types: BackupManifest.userDataTypes(),
                preferences: prefs,
                prettyPrinted: true
            )

            // Filename: stable + sortable + informative.
            let info = Bundle.main.infoDictionary
            let appV = (info?["CFBundleShortVersionString"] as? String) ?? "0"
            let build = (info?["CFBundleVersion"] as? String) ?? "0"
            let ts = timestampString(Date())

            let filename = "workouttracker-backup-v\(appV)-b\(build)-\(ts).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            try data.write(to: url, options: [.atomic])
            exportURL = url
            exportError = nil

            // Track last export time (for user confidence).
            prefs.lastBackupAt = Date()
        } catch {
            exportURL = nil
            exportError = "Export failed: \(error.localizedDescription)"
        }
    }

    private func exportFullBackupZIP() {
        guard let exporter = backupExporter else {
            fullExportURL = nil
            fullExportError = "Full backup exporter is not configured."
            return
        }

        do {
            let url = try exporter.exportBackup()
            fullExportURL = url
            fullExportError = nil

            // Track last export time (for user confidence).
            prefs.lastBackupAt = Date()
        } catch {
            fullExportURL = nil
            fullExportError = "Full backup failed: \(error.localizedDescription)"
        }
    }

    private func restoreSettingsOnly() {
        restoreError = nil
        restoreSuccess = nil
        guard let importedData else { return }

        do {
            try backupService.restorePreferencesOnly(importedData, preferences: prefs)
            restoreSuccess = "Settings restored."
        } catch {
            restoreError = error.localizedDescription
        }
    }

    private func attemptWorkoutRestore() {
        // Left as intentionally disabled in UI.
        restoreError = "Workout restore is not enabled yet."
    }

    private func timestampString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMdd-HHmmss'Z'"
        return f.string(from: d)
    }
}
