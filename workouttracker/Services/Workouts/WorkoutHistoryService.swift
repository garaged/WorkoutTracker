// File: workouttracker/Services/Workouts/WorkoutHistoryService.swift
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
        let sessions = try recentSessions(
            limit: max(limit, 200),
            includeIncomplete: includeIncomplete,
            context: context
        )

        let filtered = sessions.filter { s in
            s.exercises.contains(where: { $0.exerciseId == exerciseID })
        }

        return Array(filtered.prefix(limit))
    }

    // MARK: - New: Open-by-id (used by chart tapping)

    func session(id sessionId: UUID, context: ModelContext) throws -> WorkoutSession? {
        let sid = sessionId
        let pred = #Predicate<WorkoutSession> { s in
            s.id == sid
        }
        var fd = FetchDescriptor<WorkoutSession>(predicate: pred)
        fd.fetchLimit = 1
        return try context.fetch(fd).first
    }

    // MARK: - New: Per-exercise session timeline points (tap → open session)

    struct ExerciseSessionPoint: Identifiable, Hashable {
        var id: UUID { sessionId }

        let sessionId: UUID
        let date: Date
        let value: Double
        /// What “value” means for this point (e.g. "e1RM", "Weight", "Reps").
        let label: String
    }

    func exerciseTimeline(
        exerciseId: UUID,
        limit: Int = 40,
        includeIncomplete: Bool = true,
        context: ModelContext
    ) throws -> [ExerciseSessionPoint] {
        // We reuse your pragmatic approach: fetch a bounded “recent window” and filter in memory.
        let ss = try sessions(
            containing: exerciseId,
            limit: max(limit, 120),
            includeIncomplete: includeIncomplete,
            context: context
        )

        var out: [ExerciseSessionPoint] = []
        out.reserveCapacity(min(limit, ss.count))

        for s in ss {
            guard let best = bestPointValue(for: exerciseId, in: s) else { continue }
            out.append(ExerciseSessionPoint(
                sessionId: s.id,
                date: s.startedAt,
                value: best.value,
                label: best.label
            ))
        }

        // Chart reads nicer left-to-right (oldest → newest).
        out.sort { $0.date < $1.date }
        if out.count > limit {
            out = Array(out.suffix(limit))
        }
        return out
    }

    private func bestPointValue(for exerciseId: UUID, in session: WorkoutSession) -> (value: Double, label: String)? {
        let relevantExercises = session.exercises.filter { $0.exerciseId == exerciseId }
        guard !relevantExercises.isEmpty else { return nil }

        let completedSets = relevantExercises
            .flatMap { $0.setLogs }
            .filter { $0.completed }

        guard !completedSets.isEmpty else { return nil }

        // Prefer e1RM when possible; fallback to max weight; fallback to max reps.
        var bestE1RM: Double? = nil
        var bestWeight: Double? = nil
        var bestReps: Int? = nil

        for set in completedSets {
            let w = set.weight ?? 0
            let r = set.reps ?? 0

            if w > 0, r > 0 {
                let e1rm = w * (1.0 + (Double(r) / 30.0)) // Epley
                bestE1RM = max(bestE1RM ?? 0, e1rm)
            }
            if w > 0 {
                bestWeight = max(bestWeight ?? 0, w)
            }
            if r > 0 {
                bestReps = max(bestReps ?? 0, r)
            }
        }

        if let v = bestE1RM, v > 0 { return (v, "e1RM") }
        if let v = bestWeight, v > 0 { return (v, "Weight") }
        if let r = bestReps, r > 0 { return (Double(r), "Reps") }
        return nil
    }
}
