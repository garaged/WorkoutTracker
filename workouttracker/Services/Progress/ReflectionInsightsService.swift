import Foundation
import SwiftData

/// Computes local “reflection rate” + mood distribution over a time window.
///
/// Why this is a service (and not inside the SwiftUI view):
/// - keeps SwiftUI simple
/// - isolates fetch + aggregation logic (easy to unit test later)
/// - makes it easy to reuse the same logic in other dashboards
@MainActor
final class ReflectionInsightsService {

    struct MoodStat: Identifiable, Hashable {
        var id: String { mood.rawValue }
        let mood: SessionReflectionMood
        let count: Int
        /// Percent among sessions that have a mood (not among all sessions).
        let percentOfMoods: Double
    }

    struct Summary: Hashable {
        let windowStart: Date
        let windowEndExclusive: Date

        let completedSessions: Int
        let sessionsWithReflection: Int
        let sessionsWithMood: Int
        let sessionsWithNote: Int

        let moodOnly: Int
        let noteOnly: Int
        let bothMoodAndNote: Int

        /// 0...1 (nil when completedSessions == 0)
        let reflectionRate: Double?

        let moodStats: [MoodStat]
    }

    private let calendar: Calendar
    private let now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }

    func summarize(weeksBack: Int, context: ModelContext) throws -> Summary {
        let end = now()
        let endWeekStart = calendar.startOfWeek(for: end)
        let windowStart = calendar.date(byAdding: .weekOfYear, value: -weeksBack + 1, to: endWeekStart) ?? endWeekStart
        let windowEndExclusive = calendar.date(byAdding: .weekOfYear, value: 1, to: endWeekStart) ?? end

        // Fetch only completed sessions in the window (fast, predictable).
        let completedRaw = WorkoutSessionStatus.completed.rawValue
        let fd = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { s in
                s.startedAt >= windowStart &&
                s.startedAt < windowEndExclusive &&
                s.statusRaw == completedRaw
            },
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )

        let sessions = try context.fetch(fd)

        var withReflection = 0
        var withMood = 0
        var withNote = 0
        var moodOnly = 0
        var noteOnly = 0
        var both = 0

        var moodCounts: [SessionReflectionMood: Int] = [:]

        for s in sessions {
            let hasMood = (s.reflectionMood != nil)
            let noteTrimmed = (s.reflectionNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let hasNote = !noteTrimmed.isEmpty

            if hasMood { withMood += 1 }
            if hasNote { withNote += 1 }

            if hasMood || hasNote {
                withReflection += 1
            }

            if hasMood && hasNote {
                both += 1
            } else if hasMood {
                moodOnly += 1
            } else if hasNote {
                noteOnly += 1
            }

            if let m = s.reflectionMood {
                moodCounts[m, default: 0] += 1
            }
        }

        let totalCompleted = sessions.count
        let rate: Double? = totalCompleted > 0 ? Double(withReflection) / Double(totalCompleted) : nil

        // Stable mood ordering (doesn't require CaseIterable conformance).
        let moodOrder: [SessionReflectionMood] = [.great, .good, .neutral, .tough, .bad]
        let totalMoods = moodCounts.values.reduce(0, +)

        let moodStats: [MoodStat] = moodOrder.compactMap { mood in
            let c = moodCounts[mood, default: 0]
            guard c > 0 else { return nil }
            let pct = totalMoods > 0 ? Double(c) / Double(totalMoods) : 0
            return MoodStat(mood: mood, count: c, percentOfMoods: pct)
        }

        return Summary(
            windowStart: windowStart,
            windowEndExclusive: windowEndExclusive,
            completedSessions: totalCompleted,
            sessionsWithReflection: withReflection,
            sessionsWithMood: withMood,
            sessionsWithNote: withNote,
            moodOnly: moodOnly,
            noteOnly: noteOnly,
            bothMoodAndNote: both,
            reflectionRate: rate,
            moodStats: moodStats
        )
    }
}

// MARK: - Calendar helper (local to this file)

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? startOfDay(for: date)
    }
}
