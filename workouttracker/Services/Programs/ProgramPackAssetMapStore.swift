// workouttracker/Services/Programs/ProgramPackAssetMapStore.swift
import Foundation
import Combine

struct ProgramPackAssetMap: Codable {
    /// Slug → UUID mappings remain the compatibility bridge for already-installed packs.
    /// No schema change is required for catalog-key-based matching; install now uses
    /// these saved mappings first and falls back to catalog-aware resolution only when needed.
    var routinesBySlug: [String: UUID]
    var exercisesBySlug: [String: UUID]

    static let empty = ProgramPackAssetMap(routinesBySlug: [:], exercisesBySlug: [:])
}

enum ProgramPackAssetMapStore {
    private static let fileName = "program_assets_map_v2.json"
    private static let baseFolderName = "WorkoutTracker"

    static func load() throws -> ProgramPackAssetMap {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return .empty }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ProgramPackAssetMap.self, from: data)
    }

    static func save(_ map: ProgramPackAssetMap) throws {
        let url = try fileURL()
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(map)
        try data.write(to: url, options: [.atomic])
    }

    private static func fileURL() throws -> URL {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ProgramPackAssetMapStore", code: 1)
        }
        return root
            .appendingPathComponent(baseFolderName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
