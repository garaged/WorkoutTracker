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
    @State private var exportStatusMessage: String?

    // ZIP support bundle for troubleshooting via AppBackupExporter
    @State private var fullExportURL: URL?
    @State private var fullExportError: String?
    @State private var fullExportStatusMessage: String?

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

                if let exportStatusMessage {
                    Text(exportStatusMessage)
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
                    Label(String(localized: "backup.export.generate_support_bundle"), systemImage: "ladybug")
                }
                .disabled(backupExporter == nil)
                .accessibilityLabel(AccessibilityLabels.Buttons.exportBackup)
                .accessibilityHint(AccessibilityLabels.Buttons.exportBackupHint)

                if let url = fullExportURL {
                    ShareLink(item: url) {
                        Label(String(localized: "backup.export.share_support_bundle"), systemImage: "square.and.arrow.up.on.square")
                    }
                    .padding(.top, 4)

                    Text(url.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let fullExportStatusMessage {
                    Text(fullExportStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if backupExporter == nil {
                    Text(String(localized: "backup.export.support_bundle_unavailable"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                if let fullExportError {
                    Text(fullExportError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Text(String(localized: "backup.export.guidance"))
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
                        Text(String(localized: "backup.import.file_loaded"))
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

                        Text(AppFormatting.localizedFormat(
                            "Created: %@",
                            ExportNamingFormatter.metadataDisplayTimestamp(v.createdAt)
                        ))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(AppFormatting.localizedFormat("backup.import.settings_snapshot", v.hasPreferencesSnapshot ? AppFormatting.localized("Yes") : AppFormatting.localized("No")))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(ExportNamingFormatter.backupContentsDescription(
                            totalEntities: v.totalEntities,
                            hasPreferencesSnapshot: v.hasPreferencesSnapshot
                        ))
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

                Text(String(localized: "backup.restore.replace_warning"))
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
            let exportDate = Date()
            let data = try backupService.exportJSON(
                context: context,
                types: BackupManifest.userDataTypes(),
                preferences: prefs,
                prettyPrinted: true
            )
            let validation = try backupService.validate(data)

            let info = Bundle.main.infoDictionary
            let appV = info?["CFBundleShortVersionString"] as? String
            let build = info?["CFBundleVersion"] as? String
            let filename = ExportNamingFormatter.backupJSONFilename(
                appVersion: appV,
                build: build,
                date: exportDate
            )
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            try data.write(to: url, options: [.atomic])
            exportURL = url
            exportError = nil
            exportStatusMessage = ExportNamingFormatter.backupContentsDescription(
                totalEntities: validation.totalEntities,
                hasPreferencesSnapshot: validation.hasPreferencesSnapshot
            )
            prefs.lastBackupAt = exportDate
        } catch {
            exportURL = nil
            exportStatusMessage = nil
            exportError = "Export failed: \(error.localizedDescription)"
        }
    }

    private func exportFullBackupZIP() {
        guard let exporter = backupExporter else {
            fullExportURL = nil
            fullExportStatusMessage = nil
            fullExportError = "Full backup exporter is not configured."
            return
        }

        do {
            let url = try exporter.exportBackup()
            fullExportURL = url
            fullExportStatusMessage = ExportNamingFormatter.supportBundleDescription()
            fullExportError = nil
            prefs.lastBackupAt = Date()
        } catch {
            fullExportURL = nil
            fullExportStatusMessage = nil
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
}
