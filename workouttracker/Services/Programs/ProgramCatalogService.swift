// workouttracker/Services/Programs/ProgramCatalogService.swift
import Foundation

struct ProgramCatalogService {
    enum CatalogError: LocalizedError {
        case missingResource
        case decodeFailed
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .missingResource:
                return "program_catalog.json is missing from the app bundle."
            case .decodeFailed:
                return "Failed to decode program_catalog.json."
            case .unsupportedVersion(let v):
                return "Unsupported catalog version \(v)."
            }
        }
    }

    struct CatalogLoad {
        let formatVersion: Int
        let generatedAt: Date?
        let programs: [TrainingProgram]
        /// Present only for V2 catalogs (includes exercises + routines).
        let packV2: ProgramPackV2?
    }

    private struct Header: Codable {
        var formatVersion: Int
        var generatedAt: Date?
    }

    private struct ProgramPackV1: Codable {
        var formatVersion: Int
        var generatedAt: Date?
        var programs: [TrainingProgram]
    }

    init() {}

    func loadCatalog() throws -> CatalogLoad {
        // ✅ UI-test-only deterministic seed
        if ProcessInfo.processInfo.environment["UITESTS_SEED"] == "1" {
            return try loadSeededV2Catalog()
        }

        guard let url = Bundle.main.url(forResource: "program_catalog", withExtension: "json") else {
            throw CatalogError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try decodeCatalog(data)
    }

    // MARK: - Seeded V2 (UI tests only)

    private func loadSeededV2Catalog() throws -> CatalogLoad {
        let json = Self.seedV2JSON
        let data = Data(json.utf8)
        return try decodeCatalog(data)
    }

    private func decodeCatalog(_ data: Data) throws -> CatalogLoad {
        do {
            let pack = try ProgramPackCodec.decode(data)
            return CatalogLoad(
                formatVersion: pack.schemaVersion,
                generatedAt: pack.generatedAt,
                programs: pack.programs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
                packV2: pack.schemaVersion == ProgramPack.supportedSchemaVersion ? pack : nil
            )
        } catch let error as ProgramPackCodec.CodecError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                throw CatalogError.unsupportedVersion(version)
            case .decodeFailed:
                throw CatalogError.decodeFailed
            }
        }
    }

    /// Tiny deterministic V2 pack used only when UITESTS_SEED=1
    private static let seedV2JSON: String = """
    {
      "format_version": 2,
      "pack_id": "seed-program-v2-pack",
      "generated_at": "2026-02-22T00:00:00Z",
      "exercises": [
        {
          "slug": "goblet-squat",
          "name": "Goblet Squat",
          "catalog_key": "goblet-squat",
          "modality": "strength",
          "equipment_tags": ["dumbbell"]
        }
      ],
      "routines": [
        {
          "slug": "seed-full-body-a",
          "name": "Seed Full Body A",
          "notes": "Seed routine for UI tests",
          "items": [
            {
              "order": 1,
              "exercise_slug": "goblet-squat",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 2, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 3, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" }
              ]
            }
          ]
        }
      ],
      "programs": [
        {
          "id": "11111111-2222-3333-4444-555555555555",
          "slug": "seed-program-v2",
          "name": "Seed Program V2",
          "summary": "Deterministic catalog program for UI tests.",
          "author": "UITestHost",
          "level": "beginner",
          "tags": ["seed"],
          "equipment": ["dumbbell"],
          "weeks": [
            {
              "index": 1,
              "title": "Week 1",
              "days": [
                {
                  "index": 1,
                  "title": "Full Body A",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 45, "reference": { "kind": "routine", "slug": "seed-full-body-a" } }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
    """
}
