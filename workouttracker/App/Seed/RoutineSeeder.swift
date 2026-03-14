import Foundation
import SwiftData

/// Seeds a small "Starter Pack" (common exercises + a few routines) so first launch feels real.
///
/// Design goals:
/// - **Fresh installs** get seeded automatically (only when both Exercises and Routines are empty).
/// - **Manual import** from Settings is idempotent (adds missing items by name, won't duplicate).
/// - **Catalog upgrades** can enrich existing stores with better starter-exercise metadata without UI-owned seeding.
///
/// Image set design:
/// - We store a stable illustration key (for example: `back_squat`) in `mediaAssetName`.
/// - The UI layer can then resolve that key against the currently selected illustration set
///   (male / female / future neutral) instead of hardcoding one concrete asset name here.
@MainActor
enum RoutineSeeder {

    // MARK: - Demo (kept for UI tests / diagnostics)

    /// Seeds:
    /// - Exercises (if none exist)
    /// - A demo routine with items + planned sets (if no routines exist)
    ///
    /// Returns a user-friendly result string for your alert.
    static func seedDemoDataIfEmpty(context: ModelContext) throws -> String {
        let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
        var exercisesByName: [String: Exercise] = Dictionary(
            uniqueKeysWithValues: existingExercises.map { ($0.name.lowercased(), $0) }
        )

        if existingExercises.isEmpty {
            let demoExerciseNames = [
                "Back Squat",
                "Bench Press",
                "Deadlift",
                "Overhead Press",
                "Barbell Row",
                "Pull-Up",
                "Bicep Curl",
                "Triceps Pushdown"
            ]

            let starterDefsByName = Dictionary(
                uniqueKeysWithValues: starterExercises.map { ($0.name.lowercased(), $0) }
            )

            for name in demoExerciseNames {
                if let def = starterDefsByName[name.lowercased()] {
                    let ex = makeSeededExercise(from: def)
                    context.insert(ex)
                    exercisesByName[name.lowercased()] = ex
                } else {
                    // Defensive fallback: should not happen, but keeps demo seeding resilient.
                    let ex = Exercise(name: name, modality: .strength)
                    context.insert(ex)
                    exercisesByName[name.lowercased()] = ex
                }
            }
        }

        let existingRoutines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        guard existingRoutines.isEmpty else {
            try context.save()
            let exStatus = existingExercises.isEmpty ? "seeded" : "already exist"
            return "Exercises: \(exStatus). Routines already exist — nothing else added."
        }

        let routine = WorkoutRoutine(name: "Demo — Full Body A", notes: "Seeded demo routine with planned sets.")
        context.insert(routine)

        func ex(_ name: String) -> Exercise {
            exercisesByName[name.lowercased()]!
        }

        let items: [(Int, Exercise, Int, Int)] = [
            (0, ex("Back Squat"), 5, 150),
            (1, ex("Bench Press"), 8, 120),
            (2, ex("Barbell Row"), 10, 120),
            (3, ex("Overhead Press"), 8, 120),
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
    /// Idempotent: adds missing starter exercises/routines by name, and refreshes starter metadata.
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
        let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
        var exByName: [String: Exercise] = Dictionary(
            uniqueKeysWithValues: existingExercises.map { ($0.name.lowercased(), $0) }
        )

        var addedExercises = 0
        var updatedExercises = 0

        for def in starterExercises {
            let key = def.name.lowercased()
            if let existing = exByName[key] {
                if applyStarterMetadata(def, to: existing) {
                    updatedExercises += 1
                }
                continue
            }

            let ex = makeSeededExercise(from: def)
            context.insert(ex)
            exByName[key] = ex
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
        let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
        var exByName: [String: Exercise] = Dictionary(
            uniqueKeysWithValues: existingExercises.map { ($0.name.lowercased(), $0) }
        )

        var addedExercises = 0
        var updatedExercises = 0

        for def in starterExercises {
            let key = def.name.lowercased()
            if let existing = exByName[key] {
                if applyStarterMetadata(def, to: existing) {
                    updatedExercises += 1
                }
                continue
            }

            let ex = makeSeededExercise(from: def)
            context.insert(ex)
            exByName[key] = ex
            addedExercises += 1
        }

        let existingRoutines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        let existingRoutineNames = Set(existingRoutines.map { $0.name.lowercased() })

        var addedRoutines = 0
        for r in starterRoutines {
            if existingRoutineNames.contains(r.name.lowercased()) { continue }

            let routine = WorkoutRoutine(name: r.name, notes: r.notes)
            context.insert(routine)

            for (idx, itemDef) in r.items.enumerated() {
                guard let exercise = exByName[itemDef.exerciseName.lowercased()] else { continue }

                let item = WorkoutRoutineItem(
                    order: idx,
                    routine: routine,
                    exercise: exercise,
                    notes: itemDef.notes
                )
                item.trackingStyle = itemDef.trackingStyle
                context.insert(item)
                routine.items.append(item)

                for (setIdx, p) in itemDef.plans.enumerated() {
                    let plan = WorkoutSetPlan(
                        order: setIdx,
                        targetReps: p.targetReps,
                        targetWeight: p.targetWeight,
                        weightUnit: p.weightUnit,
                        targetRPE: p.targetRPE,
                        restSeconds: p.restSeconds,
                        routineItem: item
                    )
                    plan.targetDurationSeconds = p.targetDurationSeconds
                    plan.targetDistance = p.targetDistance

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

    /// Applies starter metadata without stomping on likely user-authored text.
    ///
    /// We do update structural catalog fields that affect picker quality:
    /// - modality
    /// - equipment tags
    /// - illustration key when missing
    /// - routine role suggestions
    ///
    /// For notes/instructions, we only fill gaps to avoid overwriting user edits by name.
    @discardableResult
    private static func applyStarterMetadata(_ def: SeedExerciseDef, to exercise: Exercise) -> Bool {
        var changed = false

        if let raw = def.modalityRaw, !raw.isEmpty, exercise.modalityRaw != raw {
            exercise.modalityRaw = raw
            changed = true
        }

        let normalizedEquipment = def.equipmentTags.joined(separator: ",")
        if !normalizedEquipment.isEmpty && exercise.equipmentTagsRaw != normalizedEquipment {
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

        if exercise.mediaAssetName == nil, let illustrationKey = def.illustrationKey, !illustrationKey.isEmpty {
            exercise.mediaKind = .bundledAsset
            exercise.mediaAssetName = illustrationKey
            changed = true
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

        let ex = Exercise(
            name: def.name,
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
            ex.modalityRaw = raw
        }

        return ex
    }

    private static func joinedRoutineRoles(_ roles: Set<ExerciseRoutineRole>) -> String? {
        let values = roles.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue)
        return values.isEmpty ? nil : values.joined(separator: ",")
    }

    // MARK: - Starter definitions (v2)

    private struct SeedExerciseDef {
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
        let exerciseName: String
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
        .init(name: "Back Squat",       modalityRaw: nil,        equipmentTags: ["barbell"],          instructions: nil, notes: nil,                                         illustrationKey: "back_squat",     routineRoles: []),
        .init(name: "Bench Press",      modalityRaw: nil,        equipmentTags: ["barbell","bench"],  instructions: nil, notes: nil,                                         illustrationKey: "bench_press",    routineRoles: []),
        .init(name: "Deadlift",         modalityRaw: nil,        equipmentTags: ["barbell"],          instructions: nil, notes: nil,                                         illustrationKey: "deadlift",       routineRoles: []),
        .init(name: "Overhead Press",   modalityRaw: nil,        equipmentTags: ["barbell"],          instructions: nil, notes: nil,                                         illustrationKey: "overhead_press", routineRoles: []),
        .init(name: "Barbell Row",      modalityRaw: nil,        equipmentTags: ["barbell"],          instructions: nil, notes: nil,                                         illustrationKey: "barbell_row",    routineRoles: []),
        .init(name: "Lat Pulldown",     modalityRaw: nil,        equipmentTags: ["machine"],          instructions: nil, notes: nil,                                         illustrationKey: "lat_pulldown",   routineRoles: []),
        .init(name: "Pull-Up",          modalityRaw: nil,        equipmentTags: ["bodyweight","bar"], instructions: nil, notes: nil,                                        illustrationKey: "pull_up",        routineRoles: []),
        .init(name: "Bicep Curl",       modalityRaw: nil,        equipmentTags: ["dumbbell"],         instructions: nil, notes: nil,                                         illustrationKey: "bicep_curl",     routineRoles: []),
        .init(name: "Triceps Pushdown", modalityRaw: nil,        equipmentTags: ["cable"],            instructions: nil, notes: nil,                                         illustrationKey: "triceps_pushdown", routineRoles: []),
        .init(name: "Plank",            modalityRaw: nil,        equipmentTags: ["bodyweight","mat"], instructions: nil, notes: "Timed hold.",                            illustrationKey: "plank",          routineRoles: []),

        .init(name: "Running",          modalityRaw: "cardio",   equipmentTags: ["cardio"],           instructions: nil, notes: nil,                                        illustrationKey: "running",        routineRoles: []),
        .init(name: "Walking",          modalityRaw: "cardio",   equipmentTags: ["cardio"],           instructions: "Use an easy conversational pace.", notes: "Good default for both warm-up and cool-down routines.", illustrationKey: "walking", routineRoles: [.warmUp, .coolDown]),
        .init(name: "Mobility Flow",    modalityRaw: "mobility", equipmentTags: ["mat"],              instructions: "Move through a short sequence of controlled mobility drills.", notes: "Useful before lifting and as a light cool-down finisher.", illustrationKey: "mobility_flow", routineRoles: [.warmUp, .coolDown]),
        .init(name: "Easy Run",         modalityRaw: "cardio",   equipmentTags: ["cardio"],           instructions: "Keep the pace easy and smooth. This should raise temperature, not create fatigue.", notes: "Use for warm-up routines when a longer cardio ramp is helpful.", illustrationKey: "running", routineRoles: [.warmUp]),
        .init(name: "Dynamic Stretching", modalityRaw: "mobility", equipmentTags: [],                  instructions: "Perform dynamic reps, not long static holds.", notes: "Better suited for warm-up than cool-down.", illustrationKey: nil, routineRoles: [.warmUp]),
        .init(name: "Stretching Flow",  modalityRaw: "mobility", equipmentTags: ["mat"],              instructions: "Use slower breathing and longer, comfortable positions.", notes: "A simple post-workout option for cool-down routines.", illustrationKey: nil, routineRoles: [.coolDown]),
        .init(name: "Breathing Reset",  modalityRaw: "mobility", equipmentTags: [],                    instructions: "Focus on nasal breathing and a gradual heart-rate drop.", notes: "Pairs well with stretching or a short walk after training.", illustrationKey: nil, routineRoles: [.coolDown])
    ]

    private static let starterRoutines: [SeedRoutineDef] = [
        .init(
            name: "Starter — Full Body A",
            notes: "3x/week. Smooth reps, leave 1–2 reps in reserve.",
            items: [
                .init(exerciseName: "Back Squat", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 150),
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 150),
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 150)
                ]),
                .init(exerciseName: "Bench Press", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120)
                ]),
                .init(exerciseName: "Barbell Row", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 10, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120)
                ]),
                .init(exerciseName: "Plank", trackingStyle: .timeOnly, notes: nil, plans: [
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 60, targetDistance: nil, targetRPE: nil, restSeconds: 60),
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 60, targetDistance: nil, targetRPE: nil, restSeconds: 60)
                ])
            ]
        ),
        .init(
            name: "Starter — Full Body B",
            notes: "Alternate with Full Body A.",
            items: [
                .init(exerciseName: "Deadlift", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 180),
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 180),
                    .init(targetReps: 5, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 180)
                ]),
                .init(exerciseName: "Overhead Press", trackingStyle: .strength, notes: nil, plans: [
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120),
                    .init(targetReps: 8, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: nil, targetDistance: nil, targetRPE: nil, restSeconds: 120)
                ]),
                .init(exerciseName: "Lat Pulldown", trackingStyle: .strength, notes: nil, plans: [
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
                .init(exerciseName: "Running", trackingStyle: .timeDistance, notes: "Easy pace.", plans: [
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 20*60, targetDistance: 3.0, targetRPE: nil, restSeconds: nil)
                ]),
                .init(exerciseName: "Walking", trackingStyle: .timeOnly, notes: "Cool-down.", plans: [
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 15*60, targetDistance: nil, targetRPE: nil, restSeconds: nil)
                ]),
                .init(exerciseName: "Mobility Flow", trackingStyle: .timeOnly, notes: "Move gently through hips/shoulders.", plans: [
                    .init(targetReps: nil, targetWeight: nil, weightUnit: .kg, targetDurationSeconds: 10*60, targetDistance: nil, targetRPE: nil, restSeconds: nil)
                ])
            ]
        )
    ]
}
