import Foundation
import SwiftData

@MainActor
enum RoutineSeeder {

    /// Creates demo routines only if none exist yet.
    /// Returns the created routines (empty if already seeded).
    static func seedDemoRoutinesIfEmpty(context: ModelContext) throws -> [WorkoutRoutine] {
        let existing = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        guard existing.isEmpty else { return [] }

        // NOTE: adjust initializer if your WorkoutRoutine init signature differs.
        // Most projects use WorkoutRoutine(name: String).
        let r1 = WorkoutRoutine(name: "Demo — Full Body A")
        let r2 = WorkoutRoutine(name: "Demo — Upper A")

        context.insert(r1)
        context.insert(r2)
        try context.save()

        return [r1, r2]
    }
}
