import Foundation
import SwiftData

@MainActor
final class WorkoutHistoryService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func recentSessions(
        limit: Int = 50,
        includeIncomplete: Bool = true,
        context: ModelContext
    ) throws -> [WorkoutSession] {
        var fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
        fd.fetchLimit = limit

        let fetched = try context.fetch(fd)
        if includeIncomplete { return fetched }
        return fetched.filter { $0.status == .completed }
    }

    func sessions(
        on day: Date,
        includeIncomplete: Bool = true,
        context: ModelContext
    ) throws -> [WorkoutSession] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let pred = #Predicate<WorkoutSession> { s in
            s.startedAt >= start && s.startedAt < end
        }

        let fetched = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: pred,
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        ))

        if includeIncomplete { return fetched }
        return fetched.filter { $0.status == .completed }
    }

    func sessions(
        containing exerciseID: UUID,
        limit: Int = 100,
        includeIncomplete: Bool = true,
        context: ModelContext
    ) throws -> [WorkoutSession] {
        let sessions = try recentSessions(limit: max(limit, 200), includeIncomplete: includeIncomplete, context: context)

        let filtered = sessions.filter { s in
            s.exercises.contains(where: { $0.exerciseId == exerciseID })
        }

        return Array(filtered.prefix(limit))
    }
}
