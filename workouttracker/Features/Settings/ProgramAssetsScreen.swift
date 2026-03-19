// workouttracker/Features/Settings/ProgramAssetsScreen.swift
import SwiftUI
import SwiftData

struct ProgramAssetsScreen: View {
    @Environment(\.modelContext) private var modelContext

    @State private var mappedRoutines: Int = 0
    @State private var mappedExercises: Int = 0
    @State private var dbRoutines: Int = 0
    @State private var dbExercises: Int = 0

    @State private var staleMappedRoutines: Int = 0
    @State private var staleMappedExercises: Int = 0

    @State private var catalogVersionLabel: String = "Unknown"
    @State private var isWorking: Bool = false

    @State private var message: String? = nil
    @State private var showMessage: Bool = false

    @State private var showResetConfirm: Bool = false

    var body: some View {
        List {
            Section {
                KeyValueRow(title: AppFormatting.localized("Mapped routines (slug → UUID)"), value: "\(mappedRoutines)")
                KeyValueRow(title: AppFormatting.localized("Mapped exercises (slug → UUID)"), value: "\(mappedExercises)")

                KeyValueRow(
                    title: AppFormatting.localized("Mapped routines missing in DB"),
                    value: "\(staleMappedRoutines)",
                    valueStyle: staleMappedRoutines > 0 ? .warning : .secondary
                )
                KeyValueRow(
                    title: AppFormatting.localized("Mapped exercises missing in DB"),
                    value: "\(staleMappedExercises)",
                    valueStyle: staleMappedExercises > 0 ? .warning : .secondary
                )
            } header: {
                Text(AppFormatting.localized("Mappings"))
            }

            Section {
                KeyValueRow(title: AppFormatting.localized("Workout routines in DB"), value: "\(dbRoutines)")
                KeyValueRow(title: AppFormatting.localized("Exercises in DB"), value: "\(dbExercises)")
            } header: {
                Text(AppFormatting.localized("Database"))
            }

            Section {
                KeyValueRow(title: AppFormatting.localized("Bundled catalog"), value: catalogVersionLabel)

                Text(AppFormatting.localized("Reinstall is idempotent: it creates missing routines/exercises and refreshes the slug mapping without overwriting your custom routines."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(AppFormatting.localized("Catalog"))
            }

            Section {
                Button {
                    Task { await reinstallCatalogAssets() }
                } label: {
                    HStack {
                        Label(AppFormatting.localized("Reinstall Catalog Assets"), systemImage: "arrow.clockwise")
                        Spacer()
                        if isWorking { ProgressView().controlSize(.small) }
                    }
                }
                .disabled(isWorking)

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label(AppFormatting.localized("Reset Program Asset Map"), systemImage: "trash")
                }
                .disabled(isWorking)
            } header: {
                Text(AppFormatting.localized("Actions"))
            } footer: {
                Text(AppFormatting.localized("Reset clears the slug → UUID mapping file. After reset, Programs may appear “not schedulable” until you reinstall catalog assets (this screen will do it for you)."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AppFormatting.localized("Program Assets"))
        .task { await refreshAll() }
        .refreshable { await refreshAll() }
        .alert(AppFormatting.localized("Program Assets"), isPresented: $showMessage) {
            Button(AppFormatting.localized("OK"), role: .cancel) { }
        } message: {
            Text(message ?? AppFormatting.localized("Done."))
        }
        .confirmationDialog(
            "Reset Program Asset Map?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(AppFormatting.localized("Reset and Reinstall Catalog Assets"), role: .destructive) {
                Task { await resetMapAndReinstall() }
            }
            Button(AppFormatting.localized("Cancel"), role: .cancel) { }
        } message: {
            Text(AppFormatting.localized("This does not delete routines or exercises from the database — it only clears the mapping file. We will reinstall catalog assets immediately after."))
        }
    }

    // MARK: - Actions

    @MainActor
    private func refreshAll() async {
        let map = (try? ProgramPackAssetMapStore.load()) ?? .empty
        mappedRoutines = map.routinesBySlug.count
        mappedExercises = map.exercisesBySlug.count

        let routines = (try? modelContext.fetch(FetchDescriptor<WorkoutRoutine>())) ?? []
        let exercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []

        dbRoutines = routines.count
        dbExercises = exercises.count

        let routineIds = Set(routines.map(\.id))
        let exerciseIds = Set(exercises.map(\.id))

        staleMappedRoutines = map.routinesBySlug.values.filter { !routineIds.contains($0) }.count
        staleMappedExercises = map.exercisesBySlug.values.filter { !exerciseIds.contains($0) }.count

        do {
            let load = try ProgramCatalogService().loadCatalog()
            catalogVersionLabel = "v\(load.formatVersion)" + (load.packV2 != nil ? " (includes assets)" : "")
        } catch {
            catalogVersionLabel = "Unavailable"
        }
    }

    @MainActor
    private func reinstallCatalogAssets() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let load = try ProgramCatalogService().loadCatalog()
            guard let pack = load.packV2, pack.formatVersion == 2 else {
                message = "No bundled V2 catalog assets found. Add a V2 program_catalog.json (format_version: 2) to enable reinstall."
                showMessage = true
                await refreshAll()
                return
            }

            let r = try ProgramPackInstallService.installAssets(from: pack, context: modelContext)
            message = "Reinstalled catalog assets.\nAdded \(r.installedRoutines) routines and \(r.installedExercises) exercises."
            showMessage = true
            await refreshAll()
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showMessage = true
            await refreshAll()
        }
    }

    @MainActor
    private func resetMapAndReinstall() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try ProgramPackAssetMapStore.save(.empty)

            let load = try ProgramCatalogService().loadCatalog()
            guard let pack = load.packV2, pack.formatVersion == 2 else {
                message = "Mapping reset. Bundled V2 catalog assets not found, so reinstall could not run. Add a V2 program_catalog.json and tap Reinstall."
                showMessage = true
                await refreshAll()
                return
            }

            let r = try ProgramPackInstallService.installAssets(from: pack, context: modelContext)
            message = "Reset mapping and reinstalled catalog assets.\nAdded \(r.installedRoutines) routines and \(r.installedExercises) exercises."
            showMessage = true
            await refreshAll()
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showMessage = true
            await refreshAll()
        }
    }
}

// MARK: - Small rows (no LabeledContent = no overload surprises)

private struct KeyValueRow: View {
    enum ValueStyle {
        case secondary
        case warning
    }

    let title: String
    let value: String
    var valueStyle: ValueStyle = .secondary

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(valueStyle == .warning ? .orange : .secondary)
        }
    }
}
