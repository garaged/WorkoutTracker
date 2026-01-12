import Foundation
import SwiftData

@MainActor
final class ProgressSummaryService {
    
    struct WeekStats: Identifiable, Hashable {
        let id: String                 // "YYYY-Www"
        let weekStart: Date
        let weekEndExclusive: Date
        
        let workoutsCompleted: Int
        let totalSetsCompleted: Int
        let totalVolume: Double
        let timeTrainedSeconds: Int
    }
    
    struct Summary: Hashable {
        let weeks: [WeekStats]
        let currentStreakDays: Int
        let longestStreakDays: Int
    }
    
    private let calendar: Calendar
    private let now: () -> Date
    
    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }
    
    func summarize(weeksBack: Int = 12, context: ModelContext) throws -> Summary {
        let end = now()
        let endWeekStart = calendar.startOfWeek(for: end)
        let windowStart = calendar.date(byAdding: .weekOfYear, value: -weeksBack + 1, to: endWeekStart)!
        let windowEndExclusive = calendar.date(byAdding: .weekOfYear, value: 1, to: endWeekStart)!
        
        let sessions = try fetchCompletedSessions(
            from: windowStart,
            toExclusive: windowEndExclusive,
            context: context
        )
        
        var weeks: [WeekStats] = []
        weeks.reserveCapacity(weeksBack)
        
        for i in 0..<weeksBack {
            let ws = calendar.date(byAdding: .weekOfYear, value: i, to: windowStart)!
            let we = calendar.date(byAdding: .weekOfYear, value: 1, to: ws)!
            
            let bucket = sessions.filter { $0.startedAt >= ws && $0.startedAt < we }
            weeks.append(aggregateWeek(bucket, weekStart: ws, weekEndExclusive: we))
        }
        
        let (current, longest) = computeStreaks(sessions: sessions, asOf: end)
        
        return Summary(
            weeks: weeks,
            currentStreakDays: current,
            longestStreakDays: longest
        )
    }
    
    // MARK: Fetch

    private func fetchCompletedSessions(
        from start: Date,
        toExclusive end: Date,
        context: ModelContext
    ) throws -> [WorkoutSession] {

        // ✅ Capture a plain String (SwiftData predicates can handle this)
        let completedRaw = WorkoutSessionStatus.completed.rawValue
        // (Alternatively: let completedRaw = "completed")

        let fd = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { s in
                s.startedAt >= start &&
                s.startedAt < end &&
                s.statusRaw == completedRaw
            }
        )

        return try context.fetch(fd)
    }
    
    // MARK: Aggregation
    
    private func aggregateWeek(_ sessions: [WorkoutSession], weekStart: Date, weekEndExclusive: Date) -> WeekStats {
        var workouts = 0
        var sets = 0
        var volume: Double = 0
        var timeSeconds = 0
        
        for s in sessions {
            workouts += 1
            timeSeconds += s.elapsedSeconds(at: s.endedAt ?? now())
            
            for ex in s.exercises {
                // assumes WorkoutSessionExercise has `setLogs: [WorkoutSetLog]`
                for log in ex.setLogs where log.completed {
                    sets += 1
                    volume += log.volumeEstimate
                }
            }
        }
        
        return WeekStats(
            id: calendar.isoWeekId(for: weekStart),
            weekStart: weekStart,
            weekEndExclusive: weekEndExclusive,
            workoutsCompleted: workouts,
            totalSetsCompleted: sets,
            totalVolume: volume,
            timeTrainedSeconds: timeSeconds
        )
    }
    
    // MARK: Streaks
    
    private func computeStreaks(sessions: [WorkoutSession], asOf end: Date) -> (current: Int, longest: Int) {
        let daysWithWorkout = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        let sorted = daysWithWorkout.sorted()
        
        // Longest
        var longest = 0
        var run = 0
        var prev: Date?
        
        for d in sorted {
            if let p = prev,
               let expected = calendar.date(byAdding: .day, value: 1, to: p),
               calendar.isDate(d, inSameDayAs: expected) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            prev = d
        }
        
        // Current streak ending today
        var current = 0
        var cursor = calendar.startOfDay(for: end)
        while daysWithWorkout.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        
        return (current, longest)
    }
}

// MARK: Helpers

private extension WorkoutSetLog {
    /// Uses actuals when present, else falls back to targets.
    var volumeEstimate: Double {
        let repsVal = Double(reps ?? targetReps ?? 0)
        let wVal = weight ?? targetWeight ?? 0
        return max(0, repsVal) * max(0, wVal)
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? startOfDay(for: date)
    }
    
    func isoWeekId(for weekStart: Date) -> String {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
        let y = comps.yearForWeekOfYear ?? 0
        let w = comps.weekOfYear ?? 0
        return String(format: "%04d-W%02d", y, w)
    }
}
