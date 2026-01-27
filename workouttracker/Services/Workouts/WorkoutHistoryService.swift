import Foundation
import SwiftData

@MainActor
final class WorkoutHistoryService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func recentSessions(limit: Int = 50, context: ModelContext) throws -> [WorkoutSession] {
        var fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
        fd.fetchLimit = limit
        return try context.fetch(fd)
            .filter { $0.endedAt != nil } // “completed”; adjust if your model differs
    }

    func sessions(on day: Date, context: ModelContext) throws -> [WorkoutSession] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let pred = #Predicate<WorkoutSession> { s in
            s.startedAt >= start && s.startedAt < end
        }

        return try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: pred,
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        ))
        .filter { $0.endedAt != nil }
    }

    func sessions(containing exerciseID: UUID, limit: Int = 100, context: ModelContext) throws -> [WorkoutSession] {
        // SwiftData predicates across nested arrays can be finicky; keep this robust:
        // fetch recent sessions, filter in-memory by exercises.
        let sessions = try recentSessions(limit: max(limit, 200), context: context)

        let filtered = sessions.filter { s in
            s.exercises.contains { $0.exerciseId == exerciseID }
        }

        return Array(filtered.prefix(limit))
    }
}
