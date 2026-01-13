import Foundation
import SwiftData

@MainActor
enum RoutineSeeder {

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
            return "Exercises: \(existingExercises.isEmpty ? "seeded" : "already exist"). Routines already exist — nothing else added."
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
}
