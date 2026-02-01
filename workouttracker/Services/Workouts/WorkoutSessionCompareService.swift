import Foundation

@MainActor
enum WorkoutSessionCompareService {

    struct SessionStats: Hashable {
        let exerciseCount: Int
        let completedSets: Int

        /// Volume computed in preferred unit (preferred weight * reps).
        let volume: Double

        /// Example: "225.0 lb × 8"
        let bestSetText: String?

        let durationSeconds: Int
        let durationText: String?
    }

    static func stats(for s: WorkoutSession, preferredUnit: WeightUnit) -> SessionStats {
        let exerciseCount = s.exercises.count

        let completed = s.exercises.flatMap(\.setLogs).filter { $0.completed }
        let completedSets = completed.count

        let volume = completed.reduce(0.0) { acc, set in
            let w = set.weight(in: preferredUnit) ?? 0
            let r = Double(set.reps ?? 0)
            return acc + (w * r)
        }

        let bestSetText: String? = {
            func score(_ set: WorkoutSetLog) -> Double {
                let w = set.weight(in: preferredUnit) ?? 0
                let r = Double(set.reps ?? 0)
                return w * r
            }

            guard let best = completed.max(by: { score($0) < score($1) }),
                  score(best) > 0 else { return nil }

            let w = (best.weight(in: preferredUnit) ?? 0)
                .formatted(.number.precision(.fractionLength(1)))
            let r = best.reps ?? 0

            return "\(w) \(preferredUnit.label) × \(r)"
        }()

        let durationSeconds: Int = {
            guard let end = s.endedAt else { return 0 }
            return max(0, Int(end.timeIntervalSince(s.startedAt)))
        }()

        let durationText: String? = durationSeconds > 0 ? formatDuration(durationSeconds) : nil

        return SessionStats(
            exerciseCount: exerciseCount,
            completedSets: completedSets,
            volume: volume,
            bestSetText: bestSetText,
            durationSeconds: durationSeconds,
            durationText: durationText
        )
    }

    static func formatDuration(_ secs: Int) -> String {
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
