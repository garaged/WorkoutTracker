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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        guard let header = try? decoder.decode(Header.self, from: data) else {
            throw CatalogError.decodeFailed
        }

        switch header.formatVersion {
        case 1:
            guard let pack = try? decoder.decode(ProgramPackV1.self, from: data) else {
                throw CatalogError.decodeFailed
            }
            return CatalogLoad(
                formatVersion: 1,
                generatedAt: pack.generatedAt,
                programs: pack.programs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
                packV2: nil
            )

        case 2:
            guard let pack = try? decoder.decode(ProgramPackV2.self, from: data) else {
                throw CatalogError.decodeFailed
            }
            return CatalogLoad(
                formatVersion: 2,
                generatedAt: pack.generatedAt,
                programs: pack.programs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
                packV2: pack
            )

        default:
            throw CatalogError.unsupportedVersion(header.formatVersion)
        }
    }

    // MARK: - Seeded V2 (UI tests only)

    private func loadSeededV2Catalog() throws -> CatalogLoad {
        let json = Self.seedV2JSON
        let data = Data(json.utf8)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        guard let pack = try? decoder.decode(ProgramPackV2.self, from: data) else {
            throw CatalogError.decodeFailed
        }

        return CatalogLoad(
            formatVersion: 2,
            generatedAt: pack.generatedAt,
            programs: pack.programs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            packV2: pack
        )
    }

    /// Tiny deterministic V2 pack used only when UITESTS_SEED=1
    private static let seedV2JSON: String = """
    {
      "format_version": 2,
      "generated_at": "2026-02-22T00:00:00Z",
      "exercises": [
        { "slug": "goblet-squat", "name": "Goblet Squat", "modality": "strength", "equipment_tags": ["dumbbell"] }
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
