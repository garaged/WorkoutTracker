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

        // Filter to the exercise (assumes WorkoutSessionExercise has `exercise: Exercise?`)
        let filtered = logs.filter { log in
            log.sessionExercise?.exerciseId == exerciseId
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
            return logs.map { $0.weight ?? $0.targetWeight ?? 0 }.max() ?? 0

        case .totalVolume:
            return logs.reduce(0) { $0 + $1.volumeEstimate }

        case .estimated1RM:
            // Best estimated 1RM for the day (Epley)
            return logs.map { $0.estimated1RM }.max() ?? 0
        }
    }
}

// MARK: helpers

private extension WorkoutSetLog {
    var repsValue: Double { Double(reps ?? targetReps ?? 0) }
    var weightValue: Double { weight ?? targetWeight ?? 0 }

    var volumeEstimate: Double {
        max(0, repsValue) * max(0, weightValue)
    }

    /// Epley formula: 1RM = w * (1 + reps/30)
    var estimated1RM: Double {
        let r = repsValue
        let w = weightValue
        guard r > 0, w > 0 else { return 0 }
        return w * (1.0 + r / 30.0)
    }
}
