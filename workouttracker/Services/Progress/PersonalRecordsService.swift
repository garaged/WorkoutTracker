import Foundation
import SwiftData

@MainActor
final class PersonalRecordsService {

    // MARK: - Public types

    struct PRDouble: Hashable {
        let value: Double
        let date: Date
        let sessionID: UUID
    }

    struct PRInt: Hashable {
        let value: Int
        let date: Date
        let sessionID: UUID
    }

    struct PersonalRecords: Hashable {
        let bestWeight: PRDouble?
        let bestReps: PRInt?
        let bestSetVolume: PRDouble?
        let bestSessionVolume: PRDouble?
        let bestEstimated1RM: PRDouble?
    }

    struct TrendPoint: Identifiable, Hashable {
        let id: UUID                 // sessionID
        let date: Date               // session.startedAt
        let sessionVolume: Double
        let bestSetWeight: Double
        let bestEstimated1RM: Double
        let bestReps: Int
    }

    enum TrendMetric: String, CaseIterable, Identifiable {
        case sessionVolume = "Volume"
        case bestEstimated1RM = "Est. 1RM"
        case bestSetWeight = "Top Weight"
        case bestReps = "Top Reps"

        var id: String { rawValue }
    }

    // MARK: - API

    func records(for exerciseID: UUID, context: ModelContext) throws -> PersonalRecords {
        let summaries = try loadSummaries(for: exerciseID, context: context)

        var bestWeight: PRDouble? = nil
        var bestReps: PRInt? = nil
        var bestSetVolume: PRDouble? = nil
        var bestSessionVolume: PRDouble? = nil
        var best1RM: PRDouble? = nil

        for s in summaries {
            if s.bestSetWeight > 0 {
                bestWeight = pickMax(bestWeight, PRDouble(value: s.bestSetWeight, date: s.date, sessionID: s.sessionID))
            }
            if s.bestReps > 0 {
                bestReps = pickMax(bestReps, PRInt(value: s.bestReps, date: s.date, sessionID: s.sessionID))
            }
            if s.bestSetVolume > 0 {
                bestSetVolume = pickMax(bestSetVolume, PRDouble(value: s.bestSetVolume, date: s.date, sessionID: s.sessionID))
            }
            if s.sessionVolume > 0 {
                bestSessionVolume = pickMax(bestSessionVolume, PRDouble(value: s.sessionVolume, date: s.date, sessionID: s.sessionID))
            }
            if s.bestEstimated1RM > 0 {
                best1RM = pickMax(best1RM, PRDouble(value: s.bestEstimated1RM, date: s.date, sessionID: s.sessionID))
            }
        }

        return PersonalRecords(
            bestWeight: bestWeight,
            bestReps: bestReps,
            bestSetVolume: bestSetVolume,
            bestSessionVolume: bestSessionVolume,
            bestEstimated1RM: best1RM
        )
    }

    func trend(
        for exerciseID: UUID,
        limit: Int = 24,
        context: ModelContext
    ) throws -> [TrendPoint] {
        let summaries = try loadSummaries(for: exerciseID, context: context)
            .sorted { $0.date < $1.date }

        let trimmed = summaries.suffix(limit)

        return trimmed.map {
            TrendPoint(
                id: $0.sessionID,
                date: $0.date,
                sessionVolume: $0.sessionVolume,
                bestSetWeight: $0.bestSetWeight,
                bestEstimated1RM: $0.bestEstimated1RM,
                bestReps: $0.bestReps
            )
        }
    }

    // MARK: - Internals

    private struct SessionSummary: Hashable {
        let sessionID: UUID
        let date: Date
        let sessionVolume: Double
        let bestSetVolume: Double
        let bestSetWeight: Double
        let bestEstimated1RM: Double
        let bestReps: Int
    }

    /// Core idea:
    /// - We compute “per-session per-exercise” rollups once.
    /// - PRs and charts are just reductions over those summaries.
    private func loadSummaries(for exerciseID: UUID, context: ModelContext) throws -> [SessionSummary] {
        // NOTE: If your completion flag differs, change this filter (endedAt != nil).
        var fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )

        // You can add a predicate here later (e.g. last 2 years) if needed.
        let sessions = try context.fetch(fd)

        var out: [SessionSummary] = []
        out.reserveCapacity(min(64, sessions.count))

        for s in sessions {
            guard s.endedAt != nil else { continue }

            // Find this exercise within the session (some sessions may include it multiple times;
            // if yours allows duplicates, you may want to merge them).
            let matching = s.exercises.filter { $0.exerciseId == exerciseID }
            guard !matching.isEmpty else { continue }

            var sessionVolume: Double = 0
            var bestSetVolume: Double = 0
            var bestSetWeight: Double = 0
            var best1RM: Double = 0
            var bestReps: Int = 0

            for ex in matching {
                for set in ex.setLogs where set.completed {
                    if let r = set.reps {
                        bestReps = max(bestReps, r)
                    }

                    if let w = set.weight {
                        bestSetWeight = max(bestSetWeight, w)
                    }

                    // Volume and 1RM need both weight and reps.
                    if let w = set.weight, let r = set.reps, r > 0, w > 0 {
                        let vol = w * Double(r)
                        sessionVolume += vol
                        bestSetVolume = max(bestSetVolume, vol)
                        best1RM = max(best1RM, estimate1RM(weight: w, reps: r))
                    }
                }
            }

            // Ignore sessions that contain the exercise but have no completed “weight x reps” sets yet.
            if sessionVolume <= 0 && bestReps <= 0 && bestSetWeight <= 0 { continue }

            out.append(SessionSummary(
                sessionID: s.id,
                date: s.startedAt,
                sessionVolume: sessionVolume,
                bestSetVolume: bestSetVolume,
                bestSetWeight: bestSetWeight,
                bestEstimated1RM: best1RM,
                bestReps: bestReps
            ))
        }

        return out
    }

    /// Opinionated default: Epley.
    /// If you prefer Brzycki or Lombardi, swap this function only.
    private func estimate1RM(weight: Double, reps: Int) -> Double {
        // Epley: 1RM = w * (1 + reps/30)
        weight * (1.0 + (Double(reps) / 30.0))
    }

    private func pickMax(_ a: PRDouble?, _ b: PRDouble) -> PRDouble {
        guard let a else { return b }
        return (b.value > a.value) ? b : a
    }

    private func pickMax(_ a: PRInt?, _ b: PRInt) -> PRInt {
        guard let a else { return b }
        return (b.value > a.value) ? b : a
    }
}
