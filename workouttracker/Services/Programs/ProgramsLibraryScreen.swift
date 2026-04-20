import SwiftUI
import Combine
import SwiftData
import UniformTypeIdentifiers

struct ProgramsLibraryScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var model = ProgramsLibraryViewModel()

    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: ProgramPackDocument?

    @State private var previewSheet: ImportPreviewSheetModel? = nil

    private struct ImportPreviewSheetModel: Identifiable {
        let id = UUID()
        let preview: ProgramImportExportService.ImportPreview
    }
    @State private var importStrategy: ProgramImportExportService.ConflictStrategy = .renameOnConflict

    enum Tab: String, CaseIterable {
        case installed = "Installed"
        case catalog = "Catalog"
    }
    @State private var tab: Tab = .installed

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(AppFormatting.localized("Programs"))
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showImporter = true
                        } label: {
                            Label(AppFormatting.localized("Import"), systemImage: "square.and.arrow.down")
                        }

                        Button {
                            Task {
                                await model.prepareExport(modelContext: modelContext) { doc in
                                    exportDocument = doc
                                    showExporter = (doc != nil)
                                }
                            }
                        } label: {
                            Label(AppFormatting.localized("Export"), systemImage: "square.and.arrow.up")
                        }
                        .disabled(model.installed.isEmpty)
                    }
                }
        }
        .task { await model.loadAll(modelContext: modelContext) }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await model.handleImportSelection(result: result) { preview in
                    previewSheet = ImportPreviewSheetModel(preview: preview)
                }
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: model.exportFilename
        ) { _ in }
        .sheet(item: $previewSheet) { sheet in
            ImportPreviewSheet(
                preview: sheet.preview,
                strategy: $importStrategy,
                onCancel: {
                    previewSheet = nil
                },
                onImport: {
                    Task {
                        await model.importFromPreview(sheet.preview, strategy: importStrategy, modelContext: modelContext)
                        previewSheet = nil
                    }
                }
            )
        }
        .alert(AppFormatting.localized("Error"), isPresented: $model.showError) {
            Button(AppFormatting.localized("OK"), role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? AppFormatting.localized("Unknown error."))
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 12) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                switch tab {
                case .installed:
                    installedSection
                case .catalog:
                    catalogSection
                }
            }
        }
    }

    private var installedSection: some View {
        Group {
            if model.installed.isEmpty {
                ContentUnavailableView(AppFormatting.localized("No Programs Yet"),
                    systemImage: "list.bullet.rectangle",
                    description: Text(AppFormatting.localized("Import a program pack, or add one from the Catalog tab."))
                )
            } else {
                Section {
                    ForEach(model.installed, id: \.id) { program in
                        NavigationLink {
                            ProgramDetailScreen(program: program)
                        } label: {
                            ProgramRow(program: program, subtitle: AppFormatting.localizedFormat("%lld weeks", Int64(program.durationWeeks)))
                        }
                    }
                    .onDelete { idx in
                        Task { await model.deleteInstalled(at: idx) }
                    }
                } header: {
                    Text(AppFormatting.localized("Installed"))
                } footer: {
                    Text(AppFormatting.localized("Export produces a V2 pack (programs + routines + exercises). Scheduling is disabled unless routines exist."))
                }
            }
        }
    }

    private var catalogSection: some View {
        Group {
            if model.catalog.isEmpty {
                ContentUnavailableView(AppFormatting.localized("Catalog Empty"),
                    systemImage: "books.vertical",
                    description: Text(AppFormatting.localized("Add program_catalog.json to your app bundle (Copy Bundle Resources)."))
                )
            } else {
                Section(AppFormatting.localized("Catalog")) {
                    ForEach(model.catalog, id: \.id) { program in
                        HStack(spacing: 12) {
                            NavigationLink {
                                ProgramDetailScreen(program: program)
                            } label: {
                                ProgramRow(program: program, subtitle: AppFormatting.localized("Catalog"))
                            }

                            Spacer()

                            let alreadyInstalled = model.isInstalled(program)

                            if alreadyInstalled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .accessibilityLabel(AppFormatting.localized("Installed"))
                                    .accessibilityIdentifier("programs.catalog.installedCheckmark")
                            } else {
                                Button {
                                    Task { await model.addCatalogProgram(program, modelContext: modelContext) }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(AppFormatting.localized("Add program to installed"))
                                .accessibilityIdentifier("programs.catalog.addButton")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - View model
@MainActor
final class ProgramsLibraryViewModel: ObservableObject {
    @Published var installed: [TrainingProgram] = []
    @Published var catalog: [TrainingProgram] = []

    @Published var showError = false
    @Published var errorMessage: String?

    let exportFilename = "workouttracker_program_pack_v2"

    private let io = ProgramImportExportService()
    private let catalogService = ProgramCatalogService()

    private var catalogPackV2: ProgramPackV2? = nil

    func loadAll(modelContext: ModelContext) async {
        do {
            installed = try await io.loadLibrary()
        } catch {
            show(error)
        }

        do {
            let load = try catalogService.loadCatalog()
            catalog = load.programs
            catalogPackV2 = load.packV2

            // Optional: eagerly install catalog assets once per app run (cheap; idempotent)
            if let pack = catalogPackV2, pack.schemaVersion == ProgramPack.supportedSchemaVersion {
                _ = try ProgramPackInstallService.installAssets(from: pack, context: modelContext)
            }
        } catch {
            catalog = []
        }
    }

    func deleteInstalled(at offsets: IndexSet) async {
        do {
            for i in offsets {
                installed = try await io.removeFromLibrary(id: installed[i].id)
            }
        } catch {
            show(error)
        }
    }

    func addCatalogProgram(_ program: TrainingProgram, modelContext: ModelContext) async {
        do {
            if let pack = catalogPackV2, pack.schemaVersion == ProgramPack.supportedSchemaVersion {
                _ = try ProgramPackInstallService.installAssets(from: pack, context: modelContext)
            }

            // ✅ If it’s already installed, do nothing (prevents duplicates even if prior installs renamed IDs)
            if isInstalled(program) { return }

            // ✅ Catalog add should not duplicate
            installed = try await io.addToLibrary(program, strategy: .keepExisting)
        } catch {
            show(error)
        }
    }

    func handleImportSelection(
        result: Result<[URL], Error>,
        onPreviewReady: (ProgramImportExportService.ImportPreview) -> Void
    ) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let preview = try await io.previewImport(fileURL: url)
            onPreviewReady(preview)
        } catch {
            show(error)
        }
    }

    func importFromPreview(
        _ preview: ProgramImportExportService.ImportPreview,
        strategy: ProgramImportExportService.ConflictStrategy,
        modelContext: ModelContext
    ) async {
        do {
            if preview.pack.schemaVersion == ProgramPack.supportedSchemaVersion {
                _ = try ProgramPackInstallService.installAssets(from: preview.pack, context: modelContext)
            }

            installed = try await io.importFromPreview(preview, strategy: strategy)
        } catch {
            show(error)
        }
    }

    func prepareExport(modelContext: ModelContext, onReady: (ProgramPackDocument?) -> Void) async {
        do {
            let data = try ProgramPackExportService.exportV2(programs: installed, context: modelContext)
            onReady(ProgramPackDocument(data: data))
        } catch {
            show(error)
            onReady(nil)
        }
    }

    private func show(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showError = true
    }
    
    private func normSlug(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func isInstalled(_ program: TrainingProgram) -> Bool {
        let installedSlugs = Set(installed.map { normSlug($0.slug) })
        return installedSlugs.contains(normSlug(program.slug))
    }
}

// MARK: - Supporting UI
private struct ProgramRow: View {
    let program: TrainingProgram
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(program.name).font(.headline)
            HStack(spacing: 8) {
                if program.level != .unknown {
                    Text(program.level.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ImportPreviewSheet: View {
    let preview: ProgramImportExportService.ImportPreview
    @Binding var strategy: ProgramImportExportService.ConflictStrategy
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(AppFormatting.localized("Pack")) {
                    LabeledContent(AppFormatting.localized("Version"), value: "\(preview.packVersion)")
                    if preview.includesAssets {
                        LabeledContent(AppFormatting.localized("Includes routines/exercises"), value: "Yes")
                    } else {
                        LabeledContent(AppFormatting.localized("Includes routines/exercises"), value: "No")
                    }
                    if let date = preview.generatedAt {
                        LabeledContent(AppFormatting.localized("Generated"), value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                    Picker(AppFormatting.localized("On conflict"), selection: $strategy) {
                        ForEach(ProgramImportExportService.ConflictStrategy.allCases, id: \.self) { s in
                            Text(label(for: s)).tag(s)
                        }
                    }
                }

                Section(AppFormatting.localizedFormat("Programs (%lld)", Int64(preview.programs.count))) {
                    ForEach(preview.programs, id: \.id) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.headline)
                            Text(AppFormatting.localizedFormat("%1$lld weeks • %2$@", Int64(p.durationWeeks), p.slug))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !preview.warnings.isEmpty {
                    Section(AppFormatting.localized("Warnings")) {
                        ForEach(preview.warnings, id: \.self) { w in
                            Text(w).font(.callout)
                        }
                    }
                }
            }
            .navigationTitle(AppFormatting.localized("Import Preview"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(AppFormatting.localized("Cancel"), action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button(AppFormatting.localized("Import"), action: onImport) }
            }
        }
    }

    private func label(for s: ProgramImportExportService.ConflictStrategy) -> String {
        switch s {
        case .keepExisting: return AppFormatting.localized("Keep existing")
        case .replaceExisting: return AppFormatting.localized("Replace existing")
        case .renameOnConflict: return AppFormatting.localized("Import as new")
        }
    }
}

struct ProgramPackDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
