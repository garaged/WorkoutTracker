import Foundation

actor ProgramImportExportService {
    enum ConflictStrategy: String, CaseIterable {
        case keepExisting
        case replaceExisting
        case renameOnConflict
    }

    struct ImportPreview: Sendable {
        let pack: ProgramPack
        let validationIssues: [ProgramPackValidator.Issue]
        let rawData: Data

        var packVersion: Int { pack.schemaVersion }
        var generatedAt: Date? { pack.generatedAt }
        var programs: [TrainingProgram] { pack.programs }
        var warnings: [String] {
            validationIssues
                .filter { $0.severity == .warning }
                .map(\.message)
        }
        var includesAssets: Bool { pack.includesAssets }
    }

    enum ServiceError: LocalizedError {
        case fileUnreadable
        case invalidPackVersion(Int)
        case decodeFailed
        case validationFailed([ProgramPackValidator.Issue])

        var errorDescription: String? {
            switch self {
            case .fileUnreadable:
                return "Couldn’t read the selected file."
            case .invalidPackVersion(let v):
                return "Unsupported program pack version: \(v)."
            case .decodeFailed:
                return "Failed to decode program pack."
            case .validationFailed(let issues):
                return issues.map(\.message).joined(separator: "\n")
            }
        }
    }

    // MARK: - Storage
    private let fileManager: FileManager
    private let baseFolderName: String
    private let libraryFileName = "program_library_v1.json"

    init(fileManager: FileManager = .default, baseFolderName: String = "WorkoutTracker") {
        self.fileManager = fileManager
        self.baseFolderName = baseFolderName
    }

    // MARK: - Library
    func loadLibrary() throws -> [TrainingProgram] {
        let url = try libraryURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)

        let pack = try ProgramPackCodec.decode(data)
        let report = ProgramPackValidator.validate(pack, options: .programOnly)
        if !report.isValid {
            throw ServiceError.validationFailed(report.errors)
        }

        return pack.programs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func saveLibrary(_ programs: [TrainingProgram]) throws {
        let url = try libraryURL()
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let pack = ProgramPack(
            schemaVersion: 1,
            packID: "program-library",
            generatedAt: Date(),
            exercises: [],
            routines: [],
            programs: programs
        )
        let data = try ProgramPackCodec.encode(pack)
        try data.write(to: url, options: [.atomic])
    }

    func removeFromLibrary(id: UUID) throws -> [TrainingProgram] {
        var library = try loadLibrary()
        library.removeAll { $0.id == id }
        try saveLibrary(library)
        return library
    }

    func addToLibrary(_ program: TrainingProgram, strategy: ConflictStrategy) throws -> [TrainingProgram] {
        var library = try loadLibrary()
        library = merge(programs: [program], into: library, strategy: strategy)
        try saveLibrary(library)
        return library
    }

    // MARK: - Import Preview (v1 or v2)
    func previewImport(fileURL: URL) throws -> ImportPreview {
        let data = try readSecurityScopedFile(fileURL)
        let pack: ProgramPack
        do {
            pack = try ProgramPackCodec.decode(data)
        } catch let error as ProgramPackCodec.CodecError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                throw ServiceError.invalidPackVersion(version)
            case .decodeFailed:
                throw ServiceError.decodeFailed
            }
        }

        let options: ProgramPackValidator.Options = pack.schemaVersion == 1 ? .programOnly : .strict
        let report = ProgramPackValidator.validate(pack, options: options)
        if !report.isValid {
            throw ServiceError.validationFailed(report.errors)
        }

        return ImportPreview(pack: pack, validationIssues: report.issues, rawData: data)
    }

    func importFromPreview(_ preview: ImportPreview, strategy: ConflictStrategy) throws -> [TrainingProgram] {
        var library = try loadLibrary()
        library = merge(programs: preview.pack.programs, into: library, strategy: strategy)
        try saveLibrary(library)
        return library
    }

    // MARK: - Merge
    private func merge(programs incoming: [TrainingProgram], into existing: [TrainingProgram], strategy: ConflictStrategy) -> [TrainingProgram] {
        var result = existing
        var byID: [UUID: Int] = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($0.element.id, $0.offset) })
        var usedSlugs = Set(result.map(\.slug))

        for p in incoming {
            if let idx = byID[p.id] {
                switch strategy {
                case .keepExisting:
                    continue
                case .replaceExisting:
                    result[idx] = p
                case .renameOnConflict:
                    var copy = p
                    copy.id = UUID()
                    copy.slug = uniquifySlug(base: copy.slug, used: usedSlugs)
                    usedSlugs.insert(copy.slug)
                    byID[copy.id] = result.count
                    result.append(copy)
                }
            } else {
                var add = p
                add.slug = uniquifySlug(base: add.slug, used: usedSlugs)
                usedSlugs.insert(add.slug)
                byID[add.id] = result.count
                result.append(add)
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func uniquifySlug(base: String, used: Set<String>) -> String {
        let normalized = TrainingProgram.makeSlug(base)
        if !used.contains(normalized) { return normalized }
        var i = 2
        while used.contains("\(normalized)-\(i)") { i += 1 }
        return "\(normalized)-\(i)"
    }

    // MARK: - File URLs
    private func libraryURL() throws -> URL {
        let base = try applicationSupportDirectory()
        return base.appendingPathComponent(libraryFileName, isDirectory: false)
    }

    private func applicationSupportDirectory() throws -> URL {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ServiceError.fileUnreadable
        }
        return root.appendingPathComponent(baseFolderName, isDirectory: true)
    }

    private func readSecurityScopedFile(_ url: URL) throws -> Data {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }
}
