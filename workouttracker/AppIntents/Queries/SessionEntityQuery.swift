import Foundation
import AppIntents
import SwiftData

struct SessionEntityQuery: EntityStringQuery {
    typealias Entity = SessionAppEntity

    init() {}

    func suggestedEntities() async throws -> [SessionAppEntity] {
        let context = try IntentModelContextFactory.makeContext()
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let activities = try context.fetch(FetchDescriptor<Activity>())
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

        let resumePlanner = SessionResumePlanner()

        guard let session = resumePlanner.currentActiveSession(from: sessions, activitiesByID: activitiesByID) else {
            return []
        }

        return [SessionAppEntity(session: session, resumePlanner: resumePlanner)]
    }

    func entities(for identifiers: [SessionAppEntity.ID]) async throws -> [SessionAppEntity] {
        guard !identifiers.isEmpty else { return [] }

        let context = try IntentModelContextFactory.makeContext()
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let wanted = Set(identifiers)
        let resumePlanner = SessionResumePlanner()

        return sessions
            .filter { wanted.contains($0.id) }
            .filter { $0.status == .inProgress && $0.endedAt == nil }
            .map { SessionAppEntity(session: $0, resumePlanner: resumePlanner) }
    }

    func entities(matching string: String) async throws -> [SessionAppEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await suggestedEntities()
        }

        let lowered = trimmed.lowercased()
        let context = try IntentModelContextFactory.makeContext()
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let resumePlanner = SessionResumePlanner()

        return sessions
            .filter { $0.status == .inProgress && $0.endedAt == nil }
            .filter { session in
                let title = (session.sourceRoutineNameSnapshot ?? "Workout Session").lowercased()
                return title.contains(lowered)
            }
            .map { SessionAppEntity(session: $0, resumePlanner: resumePlanner) }
    }
}
