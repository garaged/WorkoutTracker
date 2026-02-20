import Foundation
import SwiftData

/// Seeds a small "Starter Pack" (common exercises + a few routines) so first launch feels real.
///
/// Design goals:
/// - **Fresh installs** get seeded automatically (only when both Exercises and Routines are empty).
/// - **Manual import** from Settings is idempotent (adds missing items by name, won't duplicate).
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
            let names = [
                "Back Squat",
                "Bench Press",
                "Deadlift",
                "Overhead Press",
                "Barbell Row",
                "Pull-Up",
                "Dumbbell Curl",
                "Triceps Pushdown"
            ]

            for n in names {
                let ex = Exercise(name: n, modality: .strength)
                context.insert(ex)
                exercisesByName[n.lowercased()] = ex
            }
        }

        let existingRoutines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        guard existingRoutines.isEmpty else {
            try context.save()
            // Avoid nested quotes inside string interpolation to keep parsing robust.
            let exStatus = existingExercises.isEmpty ? "seeded" : "already exist"
            return "Exercises: \(exStatus). Routines already exist — nothing else added."
        }

        // Build a demo routine
        let routine = WorkoutRoutine(name: "Demo — Full Body A", notes: "Seeded demo routine with planned sets.")
        context.insert(routine)

        // Helper to lookup exercise by name (should exist after seeding)
        func ex(_ name: String) -> Exercise {
            exercisesByName[name.lowercased()]!
        }

        // Items: (order, exercise, default reps, rest)
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

            // 3 planned sets per exercise
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
    /// Idempotent: adds missing starter exercises/routines by name.
    static func importStarterPack(context: ModelContext) throws -> String {
        try importStarterPackInternal(context: context, mode: .manual)
    }

    // MARK: - Private

    private enum ImportMode { case freshInstall, manual }

    private static func importStarterPackInternal(context: ModelContext, mode: ImportMode) throws -> String {
        // 1) Exercises
        let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
        var exByName: [String: Exercise] = Dictionary(
            uniqueKeysWithValues: existingExercises.map { ($0.name.lowercased(), $0) }
        )

        var addedExercises = 0
        for def in starterExercises {
            let key = def.name.lowercased()
            if exByName[key] != nil { continue }

            let ex = Exercise(
                name: def.name,
                modality: .strength, // safe default; we store modalityRaw below for cardio/mobility
                instructions: def.instructions,
                notes: def.notes,
                mediaKind: .none,
                mediaAssetName: nil,
                mediaURLString: nil,
                equipmentTagsRaw: def.equipmentTags.joined(separator: ","),
                isArchived: false
            )

            if let raw = def.modalityRaw, !raw.isEmpty {
                ex.modalityRaw = raw
            }

            context.insert(ex)
            exByName[key] = ex
            addedExercises += 1
        }

        // 2) Routines
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
                    // Optional cardio/time fields exist as stored properties in your model
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
        return "\(prefix) Added exercises: \(addedExercises), added routines: \(addedRoutines). Totals → Exercises: \(totalExercises), Routines: \(totalRoutines)."
    }

    // MARK: - Starter definitions (v1)

    private struct SeedExerciseDef {
        let name: String
        let modalityRaw: String?
        let equipmentTags: [String]
        let instructions: String?
        let notes: String?
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

    /// Keep v1 small and high-quality; easy to expand later.
    private static let starterExercises: [SeedExerciseDef] = [
        .init(name: "Back Squat", modalityRaw: nil, equipmentTags: ["barbell"], instructions: nil, notes: nil),
        .init(name: "Bench Press", modalityRaw: nil, equipmentTags: ["barbell","bench"], instructions: nil, notes: nil),
        .init(name: "Deadlift", modalityRaw: nil, equipmentTags: ["barbell"], instructions: nil, notes: nil),
        .init(name: "Overhead Press", modalityRaw: nil, equipmentTags: ["barbell"], instructions: nil, notes: nil),
        .init(name: "Barbell Row", modalityRaw: nil, equipmentTags: ["barbell"], instructions: nil, notes: nil),
        .init(name: "Lat Pulldown", modalityRaw: nil, equipmentTags: ["machine"], instructions: nil, notes: nil),
        .init(name: "Pull-Up", modalityRaw: nil, equipmentTags: ["bodyweight","bar"], instructions: nil, notes: nil),
        .init(name: "Bicep Curl", modalityRaw: nil, equipmentTags: ["dumbbell"], instructions: nil, notes: nil),
        .init(name: "Triceps Pushdown", modalityRaw: nil, equipmentTags: ["cable"], instructions: nil, notes: nil),
        .init(name: "Plank", modalityRaw: nil, equipmentTags: ["bodyweight","mat"], instructions: nil, notes: "Timed hold."),
        .init(name: "Running", modalityRaw: "cardio", equipmentTags: ["cardio"], instructions: nil, notes: nil),
        .init(name: "Walking", modalityRaw: "cardio", equipmentTags: ["cardio"], instructions: nil, notes: nil),
        .init(name: "Mobility Flow", modalityRaw: "mobility", equipmentTags: ["mat"], instructions: nil, notes: "Light stretching and joint prep.")
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