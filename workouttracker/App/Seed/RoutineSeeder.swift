import Foundation
import SwiftData

/// Seeds a small "Starter Pack" (common exercises + a few routines) so first launch feels real.
///
/// Design goals:
/// - **Fresh installs** get seeded automatically (only when both Exercises and Routines are empty).
/// - **Manual import** from Settings is idempotent (adds missing items by catalog key, with safe legacy fallback).
/// - **Catalog upgrades** can enrich existing stores with better starter-exercise metadata without UI-owned seeding.
///
/// Image set design:
/// - We store a stable illustration key (for example: `back_squat`) in `mediaAssetName`.
/// - The UI layer can then resolve that key against the currently selected illustration set
///   (male / female / future neutral) instead of hardcoding one concrete asset name here.
@MainActor
enum RoutineSeeder {

    // MARK: - Demo (kept for UI tests / diagnostics)

    /// Seeds a small set of exercises plus one demo routine.
    ///
    /// Returns a user-friendly result string for your alert.
    static func seedDemoDataIfEmpty(context: ModelContext) throws -> String {
        var allExercises = try context.fetch(FetchDescriptor<Exercise>())
        var demoExercisesByCatalogKey: [String: Exercise] = [:]
        var updatedExercises = 0
        var addedExercises = 0

        let demoExerciseCatalogKeys = [
            "back-squat",
            "bench-press",
            "deadlift",
            "overhead-press",
            "barbell-row",
            "pull-up",
            "bicep-curl",
            "triceps-pushdown"
        ]

        let starterDefsByCatalogKey = Dictionary(
            uniqueKeysWithValues: starterExercises.map { ($0.catalogKey, $0) }
        )

        for catalogKey in demoExerciseCatalogKeys {
            guard let def = starterDefsByCatalogKey[catalogKey] else {
                let fallback = Exercise(name: catalogKey, catalogKey: catalogKey, modality: .strength)
                context.insert(fallback)
                allExercises.append(fallback)
                demoExercisesByCatalogKey[catalogKey] = fallback
                addedExercises += 1
                continue
            }

            if let existing = resolveStarterExercise(def, among: allExercises) {
                if applyStarterMetadata(def, to: existing) {
                    updatedExercises += 1
                }
                demoExercisesByCatalogKey[catalogKey] = existing
                continue
            }

            let exercise = makeSeededExercise(from: def)
            context.insert(exercise)
            allExercises.append(exercise)
            demoExercisesByCatalogKey[catalogKey] = exercise
            addedExercises += 1
        }

        let existingRoutines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        guard existingRoutines.isEmpty else {
            try context.save()
            return "Exercises: added \(addedExercises), updated \(updatedExercises). Routines already exist — nothing else added."
        }

        let routine = WorkoutRoutine(name: "Demo — Full Body A", notes: "Seeded demo routine with planned sets.")
        context.insert(routine)

        func ex(_ catalogKey: String) -> Exercise {
            demoExercisesByCatalogKey[catalogKey]!
        }

        let items: [(Int, Exercise, Int, Int)] = [
            (0, ex("back-squat"), 5, 150),
            (1, ex("bench-press"), 8, 120),
            (2, ex("barbell-row"), 10, 120),
            (3, ex("overhead-press"), 8, 120),
        ]

        for (order, exercise, reps, rest) in items {
            let item = WorkoutRoutineItem(order: order, routine: routine, exercise: exercise)
            context.insert(item)
            routine.items.append(item)

            for setOrder in 0..<3 {
                let plan = WorkoutSetPlan(
                    order: setOrder,
                    targetReps: reps,
                    targetWeight: nil,
                    weightUnit: .kg,
                    targetRPE: nil,
                    restSeconds: rest,
                    routineItem: item
                )
                context.insert(plan)
                item.setPlans.append(plan)
            }
        }

        routine.updatedAt = Date()
        try context.save()

        let exCount = try context.fetch(FetchDescriptor<Exercise>()).count
        let rCount = try context.fetch(FetchDescriptor<WorkoutRoutine>()).count
        return "Seeded ✅ Exercises: \(exCount), Routines: \(rCount) (created Demo — Full Body A)."
    }

    // MARK: - Starter Pack (real app)

    /// Auto-seed for fresh installs.
    /// Only runs when *both* Exercises and Routines are empty.
    static func seedStarterPackIfNeeded(context: ModelContext) throws -> String {
        let exCount = try context.fetch(FetchDescriptor<Exercise>()).count
        let rCount  = try context.fetch(FetchDescriptor<WorkoutRoutine>()).count
        guard exCount == 0 && rCount == 0 else {
            return "Starter Pack: skipped (existing data found)."
        }
        return try importStarterPackInternal(context: context, mode: .freshInstall)
    }

    /// Compatibility alias (older call sites).
    static func seedStarterPackIfEmpty(context: ModelContext) throws -> String {
        try seedStarterPackIfNeeded(context: context)
    }

    /// Manual import from Settings.
    /// Idempotent: adds missing starter exercises/routines by stable key, and refreshes starter metadata.
    static func importStarterPack(context: ModelContext) throws -> String {
        try importStarterPackInternal(context: context, mode: .manual)
    }

    /// Lightweight catalog reconciliation for existing stores.
    ///
    /// Why this exists:
    /// - moves warm-up / cool-down starter exercises into the real seed path
    /// - updates starter exercise metadata without relying on UI-owned lazy insertion
    /// - can safely add newly introduced starter exercises to an existing library
    @discardableResult
    static func reconcileStarterExerciseCatalog(context: ModelContext) throws -> String {
        var allExercises = try context.fetch(FetchDescriptor<Exercise>())
        var addedExercises = 0
        var updatedExercises = 0

        for def in starterExercises {
            if let existing = resolveStarterExercise(def, among: allExercises) {
                if applyStarterMetadata(def, to: existing) {
                    updatedExercises += 1
                }
                continue
            }

            let exercise = makeSeededExercise(from: def)
            context.insert(exercise)
            allExercises.append(exercise)
            addedExercises += 1
        }

        if addedExercises > 0 || updatedExercises > 0 {
            try context.save()
        }

        return "Starter exercise catalog reconciled ✅ Added: \(addedExercises), updated: \(updatedExercises)."
    }

    // MARK: - Private

    private enum ImportMode { case freshInstall, manual }

    private static func importStarterPackInternal(context: ModelContext, mode: ImportMode) throws -> String {
        var allExercises = try context.fetch(FetchDescriptor<Exercise>())
        var exerciseByCatalogKey: [String: Exercise] = Dictionary(
            uniqueKeysWithValues: allExercises.compactMap { exercise -> (String, Exercise)? in
                guard let catalogKey = Exercise.normalizedCatalogKey(exercise.catalogKey) else { return nil }
                return (catalogKey, exercise)
            }
        )

        var addedExercises = 0
        var updatedExercises = 0

        for def in starterExercises {
            if let existing = resolveStarterExercise(def, among: allExercises) {
                if applyStarterMetadata(def, to: existing) {
                    updatedExercises += 1
                }
                if let catalogKey = Exercise.normalizedCatalogKey(existing.catalogKey) {
                    exerciseByCatalogKey[catalogKey] = existing
                }
                continue
            }

            let exercise = makeSeededExercise(from: def)
            context.insert(exercise)
            allExercises.append(exercise)
            exerciseByCatalogKey[def.catalogKey] = exercise
            addedExercises += 1
        }

        let existingRoutines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        let existingRoutineNames = Set(existingRoutines.map { normalizedLookupValue($0.name) })

        var addedRoutines = 0
        for routineDef in starterRoutines {
            if existingRoutineNames.contains(normalizedLookupValue(routineDef.name)) { continue }

            let routine = WorkoutRoutine(name: routineDef.name, notes: routineDef.notes)
            context.insert(routine)

            for (idx, itemDef) in routineDef.items.enumerated() {
                guard let exercise = exerciseByCatalogKey[itemDef.exerciseCatalogKey] else { continue }

                let item = WorkoutRoutineItem(
                    order: idx,
                    routine: routine,
                    exercise: exercise,
                    notes: itemDef.notes
                )
                item.trackingStyle = itemDef.trackingStyle
                context.insert(item)
                routine.items.append(item)

                for (setIdx, planDef) in itemDef.plans.enumerated() {
                    let plan = WorkoutSetPlan(
                        order: setIdx,
                        targetReps: planDef.targetReps,
                        targetWeight: planDef.targetWeight,
                        weightUnit: planDef.weightUnit,
                        targetRPE: planDef.targetRPE,
                        restSeconds: planDef.restSeconds,
                        routineItem: item
                    )
                    plan.targetDurationSeconds = planDef.targetDurationSeconds
                    plan.targetDistance = planDef.targetDistance

                    context.insert(plan)
                    item.setPlans.append(plan)
                }
            }

            routine.updatedAt = Date()
            addedRoutines += 1
        }

        try context.save()

        let totalExercises = try context.fetch(FetchDescriptor<Exercise>()).count
        let totalRoutines  = try context.fetch(FetchDescriptor<WorkoutRoutine>()).count

        let prefix = (mode == .freshInstall) ? "Starter Pack ✅" : "Imported Starter Pack ✅"
        return "\(prefix) Added exercises: \(addedExercises), updated exercises: \(updatedExercises), added routines: \(addedRoutines). Totals → Exercises: \(totalExercises), Routines: \(totalRoutines)."
    }

    /// Resolves a starter exercise using the new stable catalog identity first, then legacy fields.
    ///
    /// Resolution order:
    /// 1. catalogKey
    /// 2. stable illustration key (`mediaAssetName`)
    /// 3. unique visible-name fallback for older stores
    private static func resolveStarterExercise(_ def: SeedExerciseDef, among exercises: [Exercise]) -> Exercise? {
        if let exact = exercises.first(where: { $0.catalogKey == def.catalogKey }) {
            return exact
        }

        if let illustrationKey = def.illustrationKey,
           let illustrationMatch = exercises.first(where: {
               ($0.catalogKey == nil || $0.catalogKey == def.catalogKey) && $0.mediaAssetName == illustrationKey
           }) {
            return illustrationMatch
        }

        let nameMatches = exercises.filter {
            ($0.catalogKey == nil || $0.catalogKey == def.catalogKey) &&
            normalizedLookupValue($0.name) == normalizedLookupValue(def.name)
        }

        guard nameMatches.count == 1 else { return nil }
        return nameMatches.first
    }

    /// Applies starter metadata without stomping on likely user-authored text.
    ///
    /// We do update structural catalog fields that affect picker quality:
    /// - catalogKey
    /// - modality
    /// - equipment tags
    /// - illustration key
    /// - routine role suggestions
    ///
    /// For notes/instructions, we only fill gaps to avoid overwriting user edits by legacy name matches.
    @discardableResult
    private static func applyStarterMetadata(_ def: SeedExerciseDef, to exercise: Exercise) -> Bool {
        var changed = false

        if exercise.catalogKey == nil {
            exercise.catalogKey = def.catalogKey
            changed = true
        }

        if let raw = def.modalityRaw, !raw.isEmpty, exercise.modalityRaw != raw {
            exercise.modalityRaw = raw
            changed = true
        }

        let normalizedEquipment = def.equipmentTags.joined(separator: ",")
        if exercise.equipmentTagsRaw != normalizedEquipment {
            exercise.equipmentTagsRaw = normalizedEquipment
            changed = true
        }

        let desiredRolesRaw = joinedRoutineRoles(def.routineRoles)
        if exercise.routineRolesRaw != desiredRolesRaw {
            exercise.routineRolesRaw = desiredRolesRaw
            changed = true
        }

        if exercise.instructions == nil, let instructions = def.instructions, !instructions.isEmpty {
            exercise.instructions = instructions
            changed = true
        }

        if exercise.notes == nil, let notes = def.notes, !notes.isEmpty {
            exercise.notes = notes
            changed = true
        }

        if let illustrationKey = def.illustrationKey, !illustrationKey.isEmpty {
            if exercise.mediaKind != .bundledAsset {
                exercise.mediaKind = .bundledAsset
                changed = true
            }
            if exercise.mediaAssetName != illustrationKey {
                exercise.mediaAssetName = illustrationKey
                changed = true
            }
        }

        if changed {
            exercise.updatedAt = Date()
        }

        return changed
    }

    /// Centralized constructor for seeded exercises.
    ///
    /// Why this helper matters:
    /// - keeps demo seeding and starter-pack seeding consistent
    /// - stores one stable illustration key, not a concrete male/female asset filename
    /// - makes future packs (neutral, premium, themed, etc.) a UI concern instead of a data migration
    private static func makeSeededExercise(from def: SeedExerciseDef) -> Exercise {
        let hasIllustration = !(def.illustrationKey?.isEmpty ?? true)

        let exercise = Exercise(
            name: def.name,
            catalogKey: def.catalogKey,
            modality: .strength, // safe default; we store modalityRaw below for cardio/mobility
            instructions: def.instructions,
            notes: def.notes,
            mediaKind: hasIllustration ? .bundledAsset : .none,
            mediaAssetName: def.illustrationKey,
            mediaURLString: nil,
            equipmentTagsRaw: def.equipmentTags.joined(separator: ","),
            routineRolesRaw: joinedRoutineRoles(def.routineRoles),
            isArchived: false
        )

        if let raw = def.modalityRaw, !raw.isEmpty {
            exercise.modalityRaw = raw
        }

        return exercise
    }

    private static func joinedRoutineRoles(_ roles: Set<ExerciseRoutineRole>) -> String? {
        let values = roles.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue)
        return values.isEmpty ? nil : values.joined(separator: ",")
    }

    private static func normalizedLookupValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    // MARK: - Starter definitions (v2)

    private struct SeedExerciseDef {
        let catalogKey: String
        let name: String
        let modalityRaw: String?
        let equipmentTags: [String]
        let instructions: String?
        let notes: String?
        let illustrationKey: String?
        let routineRoles: Set<ExerciseRoutineRole>
    }

    private struct SeedPlanDef {
        let targetReps: Int?
        let targetWeight: Double?
        let weightUnit: WeightUnit
        let targetDurationSeconds: Int?
        let targetDistance: Double?
        let targetRPE: Double?
        let restSeconds: Int?
    }

    private struct SeedRoutineItemDef {
        let exerciseCatalogKey: String
        let trackingStyle: ExerciseTrackingStyle
        let notes: String?
        let plans: [SeedPlanDef]
    }

    private struct SeedRoutineDef {
        let name: String
        let notes: String?
        let items: [SeedRoutineItemDef]
    }

    /// Keep the starter pack small and high-quality; easy to expand later.
    ///
    /// Warm-up / cool-down friendly exercises now live here so the picker can rely on
    /// seeded catalog data instead of lazily creating exercises inside the UI layer.
    private static let starterExercises: [SeedExerciseDef] = [
        .init(catalogKey: "back-squat",         name: "Back Squat",         modalityRaw: nil,        equipmentTags: ["barbell"],          instructions: nil, notes: nil, illustrationKey: "back_squat",       routineRoles: []),
        .init(catalogKey: "bench-press",        name: "Bench Press",        modalityRaw: nil,        equipmentTags: ["barbell", "bench"], instructions: nil, notes: nil, illustrationKey: "bench_press",      routineRoles: []),
        .init(catalogKey: "deadlift",           name: "Deadlift",           modalityRaw: nil,        equipmentTags: ["barbell"],          instructions: nil, notes: nil, illustrationKey: "deadlift",         routineRoles: []),
        .init(catalogKey: "overhead-press",     name: "Overhead Press",     modalityRaw: nil,        equipmentTags: ["barbell"],          instructions: nil, notes: nil, illustrationKey: "overhead_press",   routineRoles: []),
        .init(catalogKey: "barbell-row",        name: "Barbell Row",        modalityRaw: nil,        equipmentTags: ["barbell"],          instructions: nil, notes: nil, illustrationKey: "barbell_row",      routineRoles: []),
        .init(catalogKey: "lat-pulldown",       name: "Lat Pulldown",       modalityRaw: nil,        equipmentTags: ["machine"],          instructions: nil, notes: nil, illustrationKey: "lat_pulldown",     routineRoles: []),
        .init(catalogKey: "pull-up",            name: "Pull-Up",            modalityRaw: nil,        equipmentTags: ["bodyweight", "bar"], instructions: nil, notes: nil, illustrationKey: "pull_up",          routineRoles: []),
        .init(catalogKey: "bicep-curl",         name: "Bicep Curl",         modalityRaw: nil,        equipmentTags: ["dumbbell"],         instructions: nil, notes: nil, illustrationKey: "bicep_curl",       routineRoles: []),
        .init(catalogKey: "triceps-pushdown",   name: "Triceps Pushdown",   modalityRaw: nil,        equipmentTags: ["cable"],            instructions: nil, notes: nil, illustrationKey: "triceps_pushdown", routineRoles: []),
        .init(catalogKey: "plank",              name: "Plank",              modalityRaw: nil,        equipmentTags: ["bodyweight", "mat"], instructions: nil, notes: "Timed hold.", illustrationKey: "plank", routineRoles: []),

        .init(catalogKey: "running",            name: "Running",            modalityRaw: "cardio",   equipmentTags: ["cardio"],           instructions: nil, notes: nil, illustrationKey: "running", routineRoles: []),
        .init(catalogKey: "walking",            name: "Walking",            modalityRaw: "cardio",   equipmentTags: ["cardio"],           instructions: "Use an easy conversational pace.", notes: "Good default for both warm-up and cool-down routines.", illustrationKey: "walking", routineRoles: [.warmUp, .coolDown]),
        .init(catalogKey: "mobility-flow",      name: "Mobility Flow",      modalityRaw: "mobility", equipmentTags: ["mat"],              instructions: "Move through a short sequence of controlled mobility drills.", notes: "Useful before lifting and as a light cool-down finisher.", illustrationKey: "mobility_flow", routineRoles: [.warmUp, .coolDown]),
        .init(catalogKey: "easy-run",           name: "Easy Run",           modalityRaw: "cardio",   equipmentTags: ["cardio"],           instructions: "Keep the pace easy and smooth. This should raise temperature, not create fatigue.", notes: "Use for warm-up routines when a longer cardio ramp is helpful.", illustrationKey: "running", routineRoles: [.warmUp]),
        .init(catalogKey: "dynamic-stretching", name: "Dynamic Stretching", modalityRaw: "mobility", equipmentTags: [],                    instructions: "Perform dynamic reps, not long static holds.", notes: "Better suited for warm-up than cool-down.", illustrationKey: nil, routineRoles: [.warmUp]),
        .init(catalogKey: "stretching-flow",    name: "Stretching Flow",    modalityRaw: "mobility", equipmentTags: ["mat"],              instructions: "Use slower breathing and longer, comfortable positions.", notes: "A simple post-workout option for cool-down routines.", illustrationKey: nil, routineRoles: [.coolDown]),
        .init(catalogKey: "breathing-reset",    name: "Breathing Reset",    modalityRaw: "mobility", equipmentTags: [],                    instructions: "Focus on nasal breathing and a gradual heart-rate drop.", notes: "Pairs well with stretching or a short walk after training.", illustrationKey: nil, routineRoles: [.coolDown])
    ]

    private static let starterRoutines: [SeedRoutineDef] = [
        .init(
            name: "Starter — Full Body A",
            notes: "3x/week. Smooth reps, leave 1–2 reps in reserve.",
            items: [
                .init(exerciseCatalogKey: "back-squat", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 150),
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 150),
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 150)
                ]),
                .init(exerciseCatalogKey: "bench-press", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120)
                ]),
                .init(exerciseCatalogKey: "barbell-row", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120)
                ]),
                .init(exerciseCatalogKey: "plank", trackingStyle: .timeOnly, notes: nil, plans: [
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 60, targetDistance: nil, targetRPE: nil, restSeconds: 60),
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 60, targetDistance: nil, targetRPE: nil, restSeconds: 60)
                ])
            ]
        ),
        .init(
            name: "Starter — Full Body B",
            notes: "Alternate with Full Body A.",
            items: [
                .init(exerciseCatalogKey: "deadlift", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 180),
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 180),
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 180)
                ]),
                .init(exerciseCatalogKey: "overhead-press", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120)
                ]),
                .init(exerciseCatalogKey: "lat-pulldown", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 90),
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 90),
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 90)
                ])
            ]
        ),
        .init(
            name: "Starter — Cardio + Mobility",
            notes: "Easy/moderate effort.",
            items: [
                .init(exerciseCatalogKey: "running", trackingStyle: .timeDistance, notes: "Easy pace.", plans: [
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 20 * 60, targetDistance: 3.0, targetRPE: nil, restSeconds: nil)
                ]),
                .init(exerciseCatalogKey: "walking", trackingStyle: .timeOnly, notes: "Cool-down.", plans: [
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 15 * 60, targetDistance: nil, targetRPE: nil, restSeconds: nil)
                ]),
                .init(exerciseCatalogKey: "mobility-flow", trackingStyle: .timeOnly, notes: "Move gently through hips/shoulders.", plans: [
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 10 * 60, targetDistance: nil, targetRPE: nil, restSeconds: nil)
                ])
            ]
        )
    ]
}
