import Foundation
import AppIntents
import SwiftData

struct RoutineEntityQuery: EntityQuery, EntityStringQuery {
    func suggestedEntities() async throws -> [RoutineAppEntity] {
        let context = try IntentModelContextFactory.makeContext()
        let routines = try context.fetch(
            FetchDescriptor<WorkoutRoutine>(
                sortBy: [SortDescriptor(\WorkoutRoutine.name, order: .forward)]
            )
        )
        return routines.map(RoutineAppEntity.init(routine:))
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [RoutineAppEntity] {
        guard !identifiers.isEmpty else { return [] }

        let context = try IntentModelContextFactory.makeContext()
        let routines = try context.fetch(
            FetchDescriptor<WorkoutRoutine>(
                sortBy: [SortDescriptor(\WorkoutRoutine.name, order: .forward)]
            )
        )

        let wanted = Set(identifiers)
        return routines
            .filter { wanted.contains($0.id) }
            .map(RoutineAppEntity.init(routine:))
    }

    @MainActor
    func entities(matching string: String) async throws -> [RoutineAppEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await suggestedEntities()
        }

        let lowered = trimmed.lowercased()
        return try await suggestedEntities().filter { entity in
            entity.name.lowercased().contains(lowered) ||
            (entity.notesPreview?.lowercased().contains(lowered) ?? false)
        }
    }
}
