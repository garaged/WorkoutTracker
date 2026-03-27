// workouttracker/Services/Programs/ProgramPackExportService.swift
import Foundation
import Combine
import SwiftData

@MainActor
enum ProgramPackExportService {

    enum ExportError: LocalizedError {
        case programMissingRoutineSlug(programSlug: String)
        case missingRoutineInMap(slug: String)

        var errorDescription: String? {
            switch self {
            case .programMissingRoutineSlug(let p):
                return "Cannot export: program “\(p)” is missing routine references on one or more days."
            case .missingRoutineInMap(let slug):
                return "Cannot export: routine slug “\(slug)” is not installed (no slug→UUID mapping)."
            }
        }
    }

    static func exportV2(programs: [TrainingProgram], context: ModelContext) throws -> Data {
        let map = (try? ProgramPackAssetMapStore.load()) ?? .empty

        // Collect routine slugs required by programs (V2 rule: each TrainingDay must have a routine slug)
        var requiredRoutineSlugs: Set<String> = []
        for p in programs {
            for w in p.weeks {
                for d in w.days {
                    guard let slug = routineSlug(for: d) else {
                        throw ExportError.programMissingRoutineSlug(programSlug: p.slug)
                    }
                    requiredRoutineSlugs.insert(slug)
                }
            }
        }

        // Ensure those routines are installed/mapped
        for slug in requiredRoutineSlugs {
            if map.routinesBySlug[slug] == nil {
                throw ExportError.missingRoutineInMap(slug: slug)
            }
        }

        let routinesAll = (try? context.fetch(FetchDescriptor<WorkoutRoutine>())) ?? []
        let exercisesAll = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let routineById = Dictionary(uniqueKeysWithValues: routinesAll.map { ($0.id, $0) })
        let exerciseById = Dictionary(uniqueKeysWithValues: exercisesAll.map { ($0.id, $0) })

        var routineDTOs: [RoutineDTO] = []
        var usedExerciseIds: Set<UUID> = []

        for slug in requiredRoutineSlugs.sorted() {
            let rid = map.routinesBySlug[slug]!
            guard let routine = routineById[rid] else { continue }

            let itemDTOs: [RoutineItemDTO] = routine.items
                .sorted(by: { $0.order < $1.order })
                .map { item in
                    let ex = item.exercise
                    if let exId = ex?.id { usedExerciseIds.insert(exId) }

                    let exSlug = ex.map { ProgramPackHelpers.stableExerciseSlug(name: $0.name, catalogKey: $0.catalogKey) }
                        ?? ProgramPackHelpers.slugify("exercise")
                    let plans = item.setPlans.sorted(by: { $0.order < $1.order }).map { p in
                        SetPlanDTO(
                            order: p.order,
                            targetReps: p.targetReps,
                            targetWeight: p.targetWeight,
                            weightUnit: p.weightUnitRaw,
                            targetDurationSeconds: p.targetDurationSeconds,
                            targetDistance: p.targetDistance,
                            targetRpe: p.targetRPE,
                            restSeconds: p.restSeconds
                        )
                    }

                    return RoutineItemDTO(
                        order: item.order,
                        exerciseSlug: exSlug,
                        trackingStyle: item.trackingStyleRaw,
                        notes: item.notes,
                        setPlans: plans
                    )
                }

            routineDTOs.append(
                RoutineDTO(slug: slug, name: routine.name, notes: routine.notes, items: itemDTOs)
            )
        }

        let exerciseDTOs: [ExerciseDTO] = usedExerciseIds.sorted(by: { $0.uuidString < $1.uuidString }).compactMap { id in
            guard let ex = exerciseById[id] else { return nil }
            return ExerciseDTO(
                slug: ProgramPackHelpers.stableExerciseSlug(name: ex.name, catalogKey: ex.catalogKey),
                name: ex.name,
                catalogKey: ProgramPackHelpers.persistedCatalogKey(ex.catalogKey),
                modality: ex.modalityRaw,
                instructions: ex.instructions,
                notes: ex.notes,
                equipmentTags: ex.equipmentTags
            )
        }

        let pack = ProgramPackV2(
            formatVersion: 2,
            generatedAt: Date(),
            exercises: exerciseDTOs,
            routines: routineDTOs,
            programs: programs
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.keyEncodingStrategy = .convertToSnakeCase
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(pack)
    }

    private static func routineSlug(for day: TrainingDay) -> String? {
        let s = day.blocks.first(where: { $0.reference?.kind == .routine })?.reference?.slug
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (t?.isEmpty == false) ? t!.lowercased() : nil
    }
}

enum ProgramPackHelpers {
    static func slugify(_ input: String) -> String {
        TrainingProgram.makeSlug(input)
    }

    static func normalizedSlug(_ slug: String) -> String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedCatalogKey(_ input: String?) -> String? {
        guard let input else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    static func persistedCatalogKey(_ input: String?) -> String? {
        guard let input else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func stableExerciseSlug(name: String, catalogKey: String?) -> String {
        if let catalogKey = normalizedCatalogKey(catalogKey) {
            return slugify(catalogKey)
        }
        return slugify(name)
    }

    static func exerciseLookupSlug(for exercise: Exercise) -> String {
        stableExerciseSlug(name: exercise.name, catalogKey: exercise.catalogKey)
    }
}
