import Foundation
import SwiftData

/// Persistence + invariants for session reflections.
/// Not actor-isolated as a *type* so it can be constructed anywhere (e.g. default args),
/// but its API is `@MainActor` because SwiftData/UI contexts are main-actor driven.
final class SessionReflectionService {

    init() {}

    @MainActor
    func saveReflection(
        for session: WorkoutSession,
        mood: SessionReflectionMood?,
        note: String?,
        in context: ModelContext
    ) throws {
        session.reflectionMood = mood

        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        session.reflectionNote = (trimmed?.isEmpty ?? true) ? nil : trimmed

        if session.reflectionCreatedAt == nil,
           session.reflectionMood != nil || session.reflectionNote != nil {
            session.reflectionCreatedAt = Date()
        }

        try context.save()
    }

    @MainActor
    func clearReflection(for session: WorkoutSession, in context: ModelContext) throws {
        session.reflectionMood = nil
        session.reflectionNote = nil
        session.reflectionCreatedAt = nil
        try context.save()
    }
}
