// File: workouttracker/Services/Workouts/WorkoutSessionComparisonService.swift
import Foundation

@MainActor
final class WorkoutSessionComparisonService {

    struct BestSet: Hashable {
        let exerciseName: String
        let weight: Double?
        let reps: Int?
        let volume: Double
        let e1rm: Double?
    }

    struct SessionStats: Hashable {
        let sessionId: UUID
        let title: String
        let startedAt: Date
        let statusLabel: String

        let exercises: Int
        let completedSets: Int
        let volume: Double

        let durationSeconds: Int?
        let bestSet: BestSet?
    }

    struct Comparison: Hashable {
        let a: SessionStats
        let b: SessionStats

        var deltaVolume: Double { b.volume - a.volume }
        var deltaCompletedSets: Int { b.completedSets - a.completedSets }

        var deltaDurationSeconds: Int? {
            guard let da = a.durationSeconds, let db = b.durationSeconds else { return nil }
            return db - da
        }
    }

    func compare(_ a: WorkoutSession, _ b: WorkoutSession) -> Comparison {
        Comparison(a: stats(for: a), b: stats(for: b))
    }

    func stats(for s: WorkoutSession) -> SessionStats {
        let title = s.sourceRoutineNameSnapshot ?? "Quick Workout"
        let statusLabel: String = {
            switch s.status {
            case .inProgress: return "In progress"
            case .completed: return "Completed"
            case .abandoned: return "Abandoned"
            }
        }()

        let allSets = s.exercises.flatMap(\.setLogs)
        let completed = allSets.filter { $0.completed }

        let volume = completed.reduce(0.0) { acc, log in
            guard let w = log.weight, let r = log.reps, w > 0, r > 0 else { return acc }
            return acc + (w * Double(r))
        }

        let durationSeconds: Int? = {
            guard let end = s.endedAt else { return nil }
            return max(0, Int(end.timeIntervalSince(s.startedAt)))
        }()

        let bestSet = computeBestSet(session: s)

        return SessionStats(
            sessionId: s.id,
            title: title,
            startedAt: s.startedAt,
            statusLabel: statusLabel,
            exercises: s.exercises.count,
            completedSets: completed.count,
            volume: volume,
            durationSeconds: durationSeconds,
            bestSet: bestSet
        )
    }

    private func computeBestSet(session s: WorkoutSession) -> BestSet? {
        var best: BestSet? = nil

        for ex in s.exercises {
            let name = ex.exerciseNameSnapshot
            for set in ex.setLogs where set.completed {
                let w = set.weight ?? 0
                let r = set.reps ?? 0
                let vol = (w > 0 && r > 0) ? (w * Double(r)) : 0
                let e1rm: Double? = (w > 0 && r > 0) ? (w * (1.0 + Double(r)/30.0)) : nil

                // “Best” = max e1RM if available, else max volume.
                let candidate = BestSet(exerciseName: name, weight: set.weight, reps: set.reps, volume: vol, e1rm: e1rm)

                guard let cur = best else { best = candidate; continue }

                let curScore = cur.e1rm ?? cur.volume
                let newScore = candidate.e1rm ?? candidate.volume

                if newScore > curScore {
                    best = candidate
                }
            }
        }

        return best
    }

    func formatDuration(_ secs: Int?) -> String? {
        guard let secs else { return nil }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
