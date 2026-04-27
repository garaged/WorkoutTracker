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

    /// Deterministic V2 pack used only when UITESTS_SEED=1.
    /// It intentionally includes only the minimal programs needed to exercise
    /// linear progression, deload cadence, and double-progression behaviors.
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
        },
        {
          "slug": "dumbbell-bench-press",
          "name": "Dumbbell Bench Press",
          "catalog_key": "dumbbell-bench-press",
          "modality": "strength",
          "equipment_tags": ["dumbbell", "bench"]
        },
        {
          "slug": "one-arm-row",
          "name": "One-Arm Row",
          "catalog_key": "one-arm-row",
          "modality": "strength",
          "equipment_tags": ["dumbbell"]
        },
        {
          "slug": "romanian-deadlift",
          "name": "Romanian Deadlift",
          "catalog_key": "romanian-deadlift",
          "modality": "strength",
          "equipment_tags": ["dumbbell"]
        },
        {
          "slug": "overhead-press",
          "name": "Overhead Press",
          "catalog_key": "overhead-press",
          "modality": "strength",
          "equipment_tags": ["dumbbell"]
        },
        {
          "slug": "lat-pulldown",
          "name": "Lat Pulldown",
          "catalog_key": "lat-pulldown",
          "modality": "strength",
          "equipment_tags": ["machine"]
        },
        {
          "slug": "split-squat",
          "name": "Split Squat",
          "catalog_key": "split-squat",
          "modality": "strength",
          "equipment_tags": ["dumbbell"]
        },
        {
          "slug": "incline-db-press",
          "name": "Incline Dumbbell Press",
          "catalog_key": "incline-db-press",
          "modality": "strength",
          "equipment_tags": ["dumbbell", "bench"]
        },
        {
          "slug": "seated-cable-row",
          "name": "Seated Cable Row",
          "catalog_key": "seated-cable-row",
          "modality": "strength",
          "equipment_tags": ["machine"]
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
        },
        {
          "slug": "seed-full-body-b",
          "name": "Seed Full Body B",
          "notes": "Seed routine for linear and deload coverage",
          "items": [
            {
              "order": 1,
              "exercise_slug": "romanian-deadlift",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 8, "rest_seconds": 120, "weight_unit": "kg" },
                { "order": 2, "target_reps": 8, "rest_seconds": 120, "weight_unit": "kg" },
                { "order": 3, "target_reps": 8, "rest_seconds": 120, "weight_unit": "kg" }
              ]
            },
            {
              "order": 2,
              "exercise_slug": "overhead-press",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 2, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 3, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" }
              ]
            },
            {
              "order": 3,
              "exercise_slug": "lat-pulldown",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 2, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 3, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" }
              ]
            }
          ]
        },
        {
          "slug": "seed-full-body-c",
          "name": "Seed Full Body C",
          "notes": "Seed routine for week rotation coverage",
          "items": [
            {
              "order": 1,
              "exercise_slug": "split-squat",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 2, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 3, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" }
              ]
            },
            {
              "order": 2,
              "exercise_slug": "incline-db-press",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 2, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 3, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" }
              ]
            },
            {
              "order": 3,
              "exercise_slug": "seated-cable-row",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 12, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 2, "target_reps": 12, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 3, "target_reps": 12, "rest_seconds": 90, "weight_unit": "kg" }
              ]
            }
          ]
        },
        {
          "slug": "seed-hypertrophy-upper",
          "name": "Seed Hypertrophy Upper",
          "notes": "Accessory-style rep-range progression seed",
          "items": [
            {
              "order": 1,
              "exercise_slug": "incline-db-press",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 10, "rest_seconds": 75, "weight_unit": "kg" },
                { "order": 2, "target_reps": 10, "rest_seconds": 75, "weight_unit": "kg" },
                { "order": 3, "target_reps": 10, "rest_seconds": 75, "weight_unit": "kg" }
              ]
            },
            {
              "order": 2,
              "exercise_slug": "seated-cable-row",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 12, "rest_seconds": 75, "weight_unit": "kg" },
                { "order": 2, "target_reps": 12, "rest_seconds": 75, "weight_unit": "kg" },
                { "order": 3, "target_reps": 12, "rest_seconds": 75, "weight_unit": "kg" }
              ]
            }
          ]
        },
        {
          "slug": "seed-hypertrophy-lower",
          "name": "Seed Hypertrophy Lower",
          "notes": "Lower-body accessory-style progression seed",
          "items": [
            {
              "order": 1,
              "exercise_slug": "goblet-squat",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 12, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 2, "target_reps": 12, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 3, "target_reps": 12, "rest_seconds": 90, "weight_unit": "kg" }
              ]
            },
            {
              "order": 2,
              "exercise_slug": "romanian-deadlift",
              "tracking_style": "strength",
              "set_plans": [
                { "order": 1, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 2, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" },
                { "order": 3, "target_reps": 10, "rest_seconds": 90, "weight_unit": "kg" }
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
          "summary": "Simple linear strength seed with fixed load increases and repeat-on-failure behavior.",
          "author": "UITestHost",
          "level": "beginner",
          "tags": ["seed", "strength", "linear"],
          "equipment": ["dumbbell", "bench", "machine"],
          "weeks": [
            {
              "index": 1,
              "title": "Week 1",
              "days": [
                {
                  "index": 1,
                  "title": "Full Body A",
                  "focus": "Squat and horizontal press",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 45, "reference": { "kind": "routine", "slug": "seed-full-body-a" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "goblet-squat",
                      "exerciseNameSnapshot": "Goblet Squat",
                      "targetSets": 3,
                      "targetReps": 8,
                      "targetWeight": 22.5,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "fixedLoadIncrease", "step": 2.5 },
                        { "kind": "repeatWeekOnFailureThreshold", "failedSets": 2 }
                      ]
                    },
                    {
                      "order": 2,
                      "exerciseKey": "dumbbell-bench-press",
                      "exerciseNameSnapshot": "Dumbbell Bench Press",
                      "targetSets": 3,
                      "targetReps": 8,
                      "targetWeight": 20,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "fixedLoadIncrease", "step": 2.0 },
                        { "kind": "repeatWeekOnFailureThreshold", "failedSets": 2 }
                      ]
                    }
                  ]
                },
                {
                  "index": 3,
                  "title": "Full Body B",
                  "focus": "Hinge and vertical press",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 45, "reference": { "kind": "routine", "slug": "seed-full-body-b" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "romanian-deadlift",
                      "exerciseNameSnapshot": "Romanian Deadlift",
                      "targetSets": 3,
                      "targetReps": 8,
                      "targetWeight": 30,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "fixedLoadIncrease", "step": 2.5 },
                        { "kind": "repeatWeekOnFailureThreshold", "failedSets": 2 }
                      ]
                    }
                  ]
                },
                {
                  "index": 5,
                  "title": "Full Body C",
                  "focus": "Single-leg and upper back",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 45, "reference": { "kind": "routine", "slug": "seed-full-body-c" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "split-squat",
                      "exerciseNameSnapshot": "Split Squat",
                      "targetSets": 3,
                      "targetReps": 10,
                      "targetWeight": 16,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "fixedLoadIncrease", "step": 2.0 },
                        { "kind": "repeatWeekOnFailureThreshold", "failedSets": 2 }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "index": 2,
              "title": "Week 2",
              "days": [
                {
                  "index": 1,
                  "title": "Full Body A",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 45, "reference": { "kind": "routine", "slug": "seed-full-body-a" } }
                  ]
                },
                {
                  "index": 3,
                  "title": "Full Body B",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 45, "reference": { "kind": "routine", "slug": "seed-full-body-b" } }
                  ]
                },
                {
                  "index": 5,
                  "title": "Full Body C",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 45, "reference": { "kind": "routine", "slug": "seed-full-body-c" } }
                  ]
                }
              ]
            }
          ]
        },
        {
          "id": "22222222-3333-4444-5555-666666666666",
          "slug": "seed-deload-cadence",
          "name": "Seed Deload Cadence",
          "summary": "Deterministic deload seed with a periodic lighter week.",
          "author": "UITestHost",
          "level": "intermediate",
          "tags": ["seed", "strength", "deload"],
          "equipment": ["dumbbell", "bench", "machine"],
          "weeks": [
            {
              "index": 1,
              "title": "Build 1",
              "days": [
                {
                  "index": 1,
                  "title": "Full Body A",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 50, "reference": { "kind": "routine", "slug": "seed-full-body-a" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "goblet-squat",
                      "exerciseNameSnapshot": "Goblet Squat",
                      "targetSets": 3,
                      "targetReps": 8,
                      "targetWeight": 24,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "fixedLoadIncrease", "step": 2.0 }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "index": 2,
              "title": "Build 2",
              "days": [
                {
                  "index": 1,
                  "title": "Full Body B",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 50, "reference": { "kind": "routine", "slug": "seed-full-body-b" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "romanian-deadlift",
                      "exerciseNameSnapshot": "Romanian Deadlift",
                      "targetSets": 3,
                      "targetReps": 8,
                      "targetWeight": 34,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "fixedLoadIncrease", "step": 2.0 }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "index": 3,
              "title": "Build 3",
              "days": [
                {
                  "index": 1,
                  "title": "Full Body C",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 50, "reference": { "kind": "routine", "slug": "seed-full-body-c" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "split-squat",
                      "exerciseNameSnapshot": "Split Squat",
                      "targetSets": 3,
                      "targetReps": 10,
                      "targetWeight": 18,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "fixedLoadIncrease", "step": 2.0 }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "index": 4,
              "title": "Deload",
              "goal": "Reduce fatigue and keep movement quality high.",
              "days": [
                {
                  "index": 1,
                  "title": "Full Body A",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 40, "reference": { "kind": "routine", "slug": "seed-full-body-a" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "goblet-squat",
                      "exerciseNameSnapshot": "Goblet Squat",
                      "targetSets": 3,
                      "targetReps": 8,
                      "targetWeight": 24,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "deloadEvery", "weeks": 4, "percent": 0.15 }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        },
        {
          "id": "33333333-4444-5555-6666-777777777777",
          "slug": "seed-double-progression-hypertrophy",
          "name": "Seed Double Progression Hypertrophy",
          "summary": "Accessory-style hypertrophy seed with rep-range progression before load increases.",
          "author": "UITestHost",
          "level": "intermediate",
          "tags": ["seed", "hypertrophy", "double-progression"],
          "equipment": ["dumbbell", "bench", "machine"],
          "weeks": [
            {
              "index": 1,
              "title": "Upper / Lower Base",
              "days": [
                {
                  "index": 1,
                  "title": "Upper",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 55, "reference": { "kind": "routine", "slug": "seed-hypertrophy-upper" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "incline-db-press",
                      "exerciseNameSnapshot": "Incline Dumbbell Press",
                      "targetSets": 3,
                      "targetReps": 10,
                      "targetWeight": 16,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "doubleProgression", "minReps": 10, "maxReps": 12, "loadStep": 2.0 }
                      ]
                    },
                    {
                      "order": 2,
                      "exerciseKey": "seated-cable-row",
                      "exerciseNameSnapshot": "Seated Cable Row",
                      "targetSets": 3,
                      "targetReps": 12,
                      "targetWeight": 30,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "doubleProgression", "minReps": 12, "maxReps": 15, "loadStep": 2.5 }
                      ]
                    }
                  ]
                },
                {
                  "index": 4,
                  "title": "Lower",
                  "blocks": [
                    { "kind": "workout", "title": "Routine", "estimated_minutes": 55, "reference": { "kind": "routine", "slug": "seed-hypertrophy-lower" } }
                  ],
                  "prescriptions": [
                    {
                      "order": 1,
                      "exerciseKey": "goblet-squat",
                      "exerciseNameSnapshot": "Goblet Squat",
                      "targetSets": 3,
                      "targetReps": 12,
                      "targetWeight": 20,
                      "weightUnit": "kg",
                      "progressionRules": [
                        { "kind": "doubleProgression", "minReps": 12, "maxReps": 15, "loadStep": 2.0 }
                      ]
                    }
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
