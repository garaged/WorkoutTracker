import Foundation

public actor ProgramImportExportService {
    public enum ConflictStrategy: String, CaseIterable {
        case keepExisting
        case replaceExisting
        case renameOnConflict
    }

    public struct ImportPreview: Sendable {
        public let packVersion: Int
        public let generatedAt: Date?
        public let programs: [TrainingProgram]
        public let warnings: [String]
        public let includesAssets: Bool
        public let rawData: Data
    }

    public enum ServiceError: LocalizedError {
        case fileUnreadable
        case invalidPackVersion(Int)
        case decodeFailed
        case validationFailed([String])

        public var errorDescription: String? {
            switch self {
            case .fileUnreadable:
                return "Couldn’t read the selected file."
            case .invalidPackVersion(let v):
                return "Unsupported program pack version: \(v)."
            case .decodeFailed:
                return "Failed to decode program pack."
            case .validationFailed(let issues):
                return issues.joined(separator: "\n")
            }
        }
    }

    private struct Header: Codable {
        var formatVersion: Int
        var generatedAt: Date?
    }

    // v1 program-only pack
    private struct ProgramPackV1: Codable {
        var formatVersion: Int
        var generatedAt: Date?
        var programs: [TrainingProgram]
    }

    // MARK: - Storage
    private let fileManager: FileManager
    private let baseFolderName: String
    private let libraryFileName = "program_library_v1.json"

    public init(fileManager: FileManager = .default, baseFolderName: String = "WorkoutTracker") {
        self.fileManager = fileManager
        self.baseFolderName = baseFolderName
    }

    // MARK: - Library
    public func loadLibrary() throws -> [TrainingProgram] {
        let url = try libraryURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)

        let pack = try decoder().decode(ProgramPackV1.self, from: data)
        _ = try validate(programs: pack.programs, strict: false)

        return pack.programs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func saveLibrary(_ programs: [TrainingProgram]) throws {
        let url = try libraryURL()
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let pack = ProgramPackV1(formatVersion: 1, generatedAt: Date(), programs: programs)
        let data = try encoder().encode(pack)
        try data.write(to: url, options: [.atomic])
    }

    public func removeFromLibrary(id: UUID) throws -> [TrainingProgram] {
        var library = try loadLibrary()
        library.removeAll { $0.id == id }
        try saveLibrary(library)
        return library
    }

    public func addToLibrary(_ program: TrainingProgram, strategy: ConflictStrategy) throws -> [TrainingProgram] {
        var library = try loadLibrary()
        library = merge(programs: [program], into: library, strategy: strategy)
        try saveLibrary(library)
        return library
    }

    // MARK: - Import Preview (v1 or v2)
    public func previewImport(fileURL: URL) throws -> ImportPreview {
        let data = try readSecurityScopedFile(fileURL)

        let dec = decoder()
        guard let header = try? dec.decode(Header.self, from: data) else {
            throw ServiceError.decodeFailed
        }

        switch header.formatVersion {
        case 1:
            guard let pack = try? dec.decode(ProgramPackV1.self, from: data) else {
                throw ServiceError.decodeFailed
            }
            let warnings = try validate(programs: pack.programs, strict: true)
            return ImportPreview(
                packVersion: 1,
                generatedAt: pack.generatedAt,
                programs: pack.programs,
                warnings: warnings,
                includesAssets: false,
                rawData: data
            )

        case 2:
            guard let pack = try? dec.decode(ProgramPackV2.self, from: data) else {
                throw ServiceError.decodeFailed
            }
            var warnings = try validate(programs: pack.programs, strict: true)
            warnings.append(contentsOf: validateV2(pack))

            return ImportPreview(
                packVersion: 2,
                generatedAt: pack.generatedAt,
                programs: pack.programs,
                warnings: warnings,
                includesAssets: true,
                rawData: data
            )

        default:
            throw ServiceError.invalidPackVersion(header.formatVersion)
        }
    }

    public func importFromPreview(_ preview: ImportPreview, strategy: ConflictStrategy) throws -> [TrainingProgram] {
        var library = try loadLibrary()
        library = merge(programs: preview.programs, into: library, strategy: strategy)
        try saveLibrary(library)
        return library
    }

    // MARK: - Validation
    private func validate(programs: [TrainingProgram], strict: Bool) throws -> [String] {
        var warnings: [String] = []
        var errors: [String] = []

        if programs.isEmpty {
            if strict { errors.append("Pack contains no programs.") }
            else { warnings.append("Library has no programs yet.") }
        }

        let ids = programs.map(\.id)
        let dupIDs = Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.map(\.key)
        if !dupIDs.isEmpty {
            errors.append("Pack has duplicate program ids (\(dupIDs.count)).")
        }

        for p in programs {
            if p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("A program has an empty name.")
            }
            if p.weeks.isEmpty {
                warnings.append("“\(p.name)” has no weeks yet.")
                continue
            }
            let weekIndexes = p.weeks.map(\.index)
            if Set(weekIndexes).count != weekIndexes.count {
                errors.append("“\(p.name)” has duplicate week indices.")
            }
        }

        if strict, !errors.isEmpty { throw ServiceError.validationFailed(errors) }
        if !errors.isEmpty { warnings.append(contentsOf: errors) }
        return warnings
    }

    private func validateV2(_ pack: ProgramPackV2) -> [String] {
        var w: [String] = []

        if pack.exercises.isEmpty { w.append("V2 pack has 0 exercises (will create placeholder exercises for routine items).") }
        if pack.routines.isEmpty { w.append("V2 pack has 0 routines (program scheduling will be disabled).") }

        let duplicateExerciseSlugs = Dictionary(grouping: pack.exercises.map { ProgramPackHelpers.normalizedSlug($0.slug) }, by: { $0 })
            .filter { $1.count > 1 }
            .keys
            .sorted()
        if !duplicateExerciseSlugs.isEmpty {
            w.append("V2 pack has duplicate exercise slugs (\(duplicateExerciseSlugs.count)); older imports may resolve them ambiguously.")
        }

        let duplicateCatalogKeys = Dictionary(
            grouping: pack.exercises.compactMap { ProgramPackHelpers.normalizedCatalogKey($0.catalogKey) },
            by: { $0 }
        )
        .filter { $1.count > 1 }
        .keys
        .sorted()
        if !duplicateCatalogKeys.isEmpty {
            w.append("V2 pack has duplicate built-in catalog keys (\(duplicateCatalogKeys.count)); built-in exercise matching may be ambiguous.")
        }

        let availableExerciseSlugs = Set(pack.exercises.map { ProgramPackHelpers.normalizedSlug($0.slug) })
        let missingRoutineExerciseRefs = Set(
            pack.routines.flatMap { routine in
                routine.items.compactMap { item in
                    let exerciseSlug = ProgramPackHelpers.normalizedSlug(item.exerciseSlug)
                    return availableExerciseSlugs.contains(exerciseSlug) ? nil : exerciseSlug
                }
            }
        )
        if !missingRoutineExerciseRefs.isEmpty {
            w.append("V2 pack has routines that reference missing exercise slugs (\(missingRoutineExerciseRefs.count)); placeholder exercises may be created during install.")
        }

        // V2 rule: each TrainingDay should reference a routine slug
        for p in pack.programs {
            for week in p.weeks {
                for day in week.days {
                    let slug = day.blocks.first(where: { $0.reference?.kind == .routine })?.reference?.slug
                    if (slug?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                        w.append("Program “\(p.name)” has a day without a routine reference (scheduling disabled until fixed).")
                        break
                    }
                }
            }
        }

        return Array(Set(w)).sorted()
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

    // MARK: - JSON config
    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
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
