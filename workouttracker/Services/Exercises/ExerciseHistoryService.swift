import Foundation
import SwiftData

@MainActor
final class ExerciseHistoryService {

    enum Metric: String, CaseIterable {
        case bestWeight
        case totalVolume
        case estimated1RM
    }

    struct Point: Identifiable, Hashable {
        let id = UUID()
        let day: Date            // startOfDay
        let value: Double
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func series(
        exerciseId: UUID,
        metric: Metric,
        range: DateInterval,
        context: ModelContext
    ) throws -> [Point] {

        // Fetch completed logs in time range (then filter by exercise via relationship).
        let logs = try fetchCompletedLogs(
            from: range.start,
            toExclusive: range.end,
            context: context
        )

        // Filter to the exercise and default core-progress view (.main only).
        let filtered = logs.filter { log in
            log.sessionExercise?.exerciseId == exerciseId &&
            log.sessionExercise?.segment == .main
        }

        // Group by day
        var buckets: [Date: [WorkoutSetLog]] = [:]
        for log in filtered {
            let day = calendar.startOfDay(for: log.completedAt ?? Date.distantPast)
            buckets[day, default: []].append(log)
        }

        return buckets.keys.sorted().map { day in
            let dayLogs = buckets[day] ?? []
            return Point(day: day, value: compute(metric: metric, logs: dayLogs))
        }
    }

    // MARK: Fetch

    private func fetchCompletedLogs(from start: Date, toExclusive end: Date, context: ModelContext) throws -> [WorkoutSetLog] {
        let fd = FetchDescriptor<WorkoutSetLog>(
            predicate: #Predicate { log in
                log.completed == true &&
                log.completedAt != nil &&
                log.completedAt! >= start &&
                log.completedAt! < end
            },
            sortBy: [
                SortDescriptor(\WorkoutSetLog.completedAt, order: .forward)
            ]
        )
        return try context.fetch(fd)
    }

    // MARK: Metric math

    private func compute(metric: Metric, logs: [WorkoutSetLog]) -> Double {
        switch metric {
        case .bestWeight:
            return logs.compactMap { positiveDouble($0.weight) }.max() ?? 0

        case .totalVolume:
            return logs.reduce(0) { $0 + volumeEstimate(for: $1) }

        case .estimated1RM:
            // Best estimated 1RM for the day (Epley)
            return logs.compactMap(estimated1RM).max() ?? 0
        }
    }

    private func positiveDouble(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func positiveInt(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func volumeEstimate(for log: WorkoutSetLog) -> Double {
        guard let reps = positiveInt(log.reps), let weight = positiveDouble(log.weight) else { return 0 }
        return weight * Double(reps)
    }

    /// Epley formula: 1RM = w * (1 + reps/30)
    private func estimated1RM(for log: WorkoutSetLog) -> Double? {
        guard let reps = positiveInt(log.reps), let weight = positiveDouble(log.weight) else { return nil }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}
