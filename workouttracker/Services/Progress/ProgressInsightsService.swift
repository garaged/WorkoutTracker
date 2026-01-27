import Foundation
import SwiftData

@MainActor
final class ProgressInsightsService {

    struct ExerciseDelta: Identifiable, Hashable {
        let id: UUID                 // exerciseId
        let name: String
        let lastDate: Date

        let lastVolume: Double
        let prevVolume: Double
        let deltaVolume: Double
        let pctDeltaVolume: Double?

        let stalled: Bool
    }

    struct TargetCard: Identifiable, Hashable {
        let id: UUID                 // exerciseId
        let name: String
        let text: String
        let targetWeight: Double?
        let targetReps: Int?
    }

    struct Summary: Hashable {
        let windowStart: Date
        let windowEnd: Date

        let topGainers: [ExerciseDelta]
        let topDecliners: [ExerciseDelta]
        let stalled: [ExerciseDelta]
        let targets: [TargetCard]
    }

    private let calendar: Calendar
    private let now: () -> Date
    private let prService: PersonalRecordsService

    init(
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        prService: PersonalRecordsService? = nil
    ) {
        self.calendar = calendar
        self.now = now
        self.prService = prService ?? PersonalRecordsService()
    }

    func summarize(
        weeksBack: Int,
        maxTargets: Int = 5,
        context: ModelContext
    ) throws -> Summary {

        let end = now()
        let start = calendar.date(byAdding: .day, value: -(weeksBack * 7), to: end) ?? end

        // Fetch a window of sessions; filter completion in-memory (safe + predictable).
        let desc = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .forward)]
        )
        let sessions = try context.fetch(desc)
            .filter { $0.startedAt >= start && $0.startedAt <= end }
            .filter { $0.status == .completed }

        // Build per-exercise time series of session-volume.
        struct Point {
            let date: Date
            let volume: Double
        }

        var series: [UUID: (name: String, points: [Point])] = [:]
        series.reserveCapacity(64)

        for s in sessions {
            for ex in s.exercises {
                let vol = sessionVolume(ex)
                guard vol > 0 else { continue }

                if series[ex.exerciseId] == nil {
                    series[ex.exerciseId] = (ex.exerciseNameSnapshot, [])
                }
                series[ex.exerciseId]?.points.append(Point(date: s.startedAt, volume: vol))
            }
        }

        // Compute deltas + stalls.
        var deltas: [ExerciseDelta] = []
        deltas.reserveCapacity(series.count)

        for (exerciseId, payload) in series {
            let pts = payload.points.sorted { $0.date < $1.date }
            guard pts.count >= 1 else { continue }

            let last = pts[pts.count - 1]
            let prev = pts.count >= 2 ? pts[pts.count - 2] : nil
            let prevPrev = pts.count >= 3 ? pts[pts.count - 3] : nil

            let lastVol = last.volume
            let prevVol = prev?.volume ?? 0
            let delta = (prev == nil) ? 0 : (lastVol - prevVol)
            let pct: Double? = (prevVol > 0) ? (delta / prevVol) : nil

            let stalled: Bool = {
                guard let prev, let prevPrev else { return false }
                // No improvement across last 3 data points (simple + robust).
                return last.volume <= prev.volume && prev.volume <= prevPrev.volume
            }()

            deltas.append(.init(
                id: exerciseId,
                name: payload.name,
                lastDate: last.date,
                lastVolume: lastVol,
                prevVolume: prevVol,
                deltaVolume: delta,
                pctDeltaVolume: pct,
                stalled: stalled
            ))
        }

        let comparable = deltas.filter { $0.prevVolume > 0 } // only those with at least 2 points
        let topGainers = Array(comparable.sorted { $0.deltaVolume > $1.deltaVolume }.prefix(5))
        let topDecliners = Array(comparable.sorted { $0.deltaVolume < $1.deltaVolume }.prefix(5))
        let stalled = Array(deltas.filter { $0.stalled }.sorted { $0.lastDate > $1.lastDate }.prefix(5))

        // Targets: pick most recently trained exercises and ask PR service for a next target.
        let recentExercises = Array(deltas.sorted { $0.lastDate > $1.lastDate }.prefix(maxTargets))
        var targets: [TargetCard] = []
        targets.reserveCapacity(recentExercises.count)

        for e in recentExercises {
            let rec = try prService.records(for: e.id, context: context)
            if let t = try prService.nextTarget(for: e.id, records: rec, context: context) {
                targets.append(.init(
                    id: e.id,
                    name: e.name,
                    text: t.text,
                    targetWeight: t.targetWeight,
                    targetReps: t.targetReps
                ))
            }
        }

        return Summary(
            windowStart: start,
            windowEnd: end,
            topGainers: topGainers,
            topDecliners: topDecliners,
            stalled: stalled,
            targets: targets
        )
    }

    private func sessionVolume(_ ex: WorkoutSessionExercise) -> Double {
        ex.setLogs.reduce(0.0) { acc, set in
            guard set.completed else { return acc }
            guard let w = set.weight, let r = set.reps, w > 0, r > 0 else { return acc }
            return acc + (w * Double(r))
        }
    }
}
