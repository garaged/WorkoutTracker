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
            Section(AppFormatting.localized("Export")) {
                Button {
                    exportBackupJSON()
                } label: {
                    Label(AppFormatting.localized("Generate JSON Backup"), systemImage: "square.and.arrow.up")
                }

                if let url = exportURL {
                    ShareLink(item: url) {
                        Label(AppFormatting.localized("Share JSON Backup"), systemImage: "square.and.arrow.up.on.square")
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
                    Label(AppFormatting.localized("Generate Full Backup (ZIP)"), systemImage: "ladybug")
                }
                .disabled(backupExporter == nil)
                .accessibilityLabel(AccessibilityLabels.Buttons.exportBackup)
                .accessibilityHint(AccessibilityLabels.Buttons.exportBackupHint)

                if let url = fullExportURL {
                    ShareLink(item: url) {
                        Label(AppFormatting.localized("Share Full Backup"), systemImage: "square.and.arrow.up.on.square")
                    }
                    .padding(.top, 4)

                    Text(url.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if backupExporter == nil {
                    Text(AppFormatting.localized("Full backup export isn’t configured yet. Add an exporter in SettingsScreen via .environment(\\.backupExporter, AppBackupExporter())."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                if let fullExportError {
                    Text(fullExportError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Text(AppFormatting.localized("JSON is best for restore. ZIP is best for debugging (logs + settings + data snapshot)."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Section(AppFormatting.localized("Import")) {
                Button {
                    showImporter = true
                } label: {
                    Label(AppFormatting.localized("Select JSON Backup File"), systemImage: "square.and.arrow.down")
                }

                if let v = importedValidation {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppFormatting.localized("Backup found"))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(AppFormatting.localizedFormat("Schema v%lld", Int64(v.schemaVersion)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let appV = v.appVersion {
                            if let b = v.appBuild {
                                Text(AppFormatting.localizedFormat("App: %@ (%@)", appV, b))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(AppFormatting.localizedFormat("App: %@", appV))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let dev = v.deviceName {
                            let os = v.systemVersion ?? "—"
                            Text(AppFormatting.localizedFormat("Device: %@ • iOS %@", dev, os))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Text(AppFormatting.localizedFormat("Created: %@", v.createdAt.formatted(date: .abbreviated, time: .shortened)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(AppFormatting.localizedFormat("Preferences snapshot: %@", v.hasPreferencesSnapshot ? AppFormatting.localized("Yes") : AppFormatting.localized("No")))
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
                            Text(AppFormatting.localized("Total"))
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

            Section(AppFormatting.localized("Restore")) {
                Button {
                    restoreSettingsOnly()
                } label: {
                    Label(AppFormatting.localized("Restore Settings From Backup"), systemImage: "gearshape.arrow.triangle.2.circlepath")
                }
                .disabled(importedData == nil)

                Button(role: .destructive) {
                    restoreAllWorkoutData()
                } label: {
                    Label(AppFormatting.localized("Restore Workout Data"), systemImage: "externaldrive.badge.plus")
                }
                .disabled(importedData == nil)

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

                Text(AppFormatting.localized("Workout restore replaces the current backed-up data snapshot in this app install. Use a fresh JSON backup first if you want a rollback point."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AppFormatting.localized("Backup & Restore"))
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

            let info = Bundle.main.infoDictionary
            let appV = (info?["CFBundleShortVersionString"] as? String) ?? "0"
            let build = (info?["CFBundleVersion"] as? String) ?? "0"
            let ts = timestampString(Date())

            let filename = "workouttracker-backup-v\(appV)-b\(build)-\(ts).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            try data.write(to: url, options: [.atomic])
            exportURL = url
            exportError = nil
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

    private func restoreAllWorkoutData() {
        restoreError = nil
        restoreSuccess = nil
        guard let importedData else { return }

        do {
            try backupService.restoreWorkoutData(importedData, context: context)
            restoreSuccess = "Workout data restored. Current backed-up entities were replaced with the imported snapshot."
        } catch {
            restoreError = error.localizedDescription
        }
    }

    private func timestampString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMdd-HHmmss'Z'"
        return f.string(from: d)
    }
}
