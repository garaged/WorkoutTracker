import Foundation
import SwiftData

@MainActor
struct AnalyticsHistoryAdapter {
    func loadExercisePerformanceSamples(
        for exerciseID: UUID? = nil,
        includeIncompleteSessions: Bool = false,
        context: ModelContext
    ) throws -> [ExercisePerformanceSample] {
        let fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .forward)]
        )
        let sessions = try context.fetch(fd)

        var samples: [ExercisePerformanceSample] = []

        for session in sessions {
            if !includeIncompleteSessions, session.status != .completed {
                continue
            }

            let matchingExercises: [WorkoutSessionExercise]
            if let exerciseID {
                matchingExercises = session.exercises.filter { $0.exerciseId == exerciseID }
            } else {
                matchingExercises = session.exercises
            }

            for exercise in matchingExercises {
                let orderedLogs = exercise.orderedSetLogs
                var previousCompletedAt: Date? = nil

                for log in orderedLogs {
                    let actualRestSeconds: Int?
                    if let previousCompletedAt, let completedAt = log.completedAt {
                        actualRestSeconds = max(0, Int(completedAt.timeIntervalSince(previousCompletedAt)))
                    } else {
                        actualRestSeconds = nil
                    }

                    let performedAt = log.completedAt ?? session.startedAt

                    samples.append(
                        ExercisePerformanceSample(
                            id: log.id,
                            exerciseID: exercise.exerciseId,
                            exerciseName: exercise.exerciseNameSnapshot,
                            sessionID: session.id,
                            sessionStartedAt: session.startedAt,
                            performedAt: performedAt,
                            segment: exercise.segment,
                            weight: log.weight,
                            reps: log.reps,
                            isCompleted: log.completed,
                            plannedRestSeconds: log.targetRestSeconds,
                            actualRestSeconds: actualRestSeconds
                        )
                    )

                    if log.completed, let completedAt = log.completedAt {
                        previousCompletedAt = completedAt
                    }
                }
            }
        }

        return samples
    }

    func loadSessionAnalyticsSamples(
        window: DateInterval? = nil,
        context: ModelContext
    ) throws -> [SessionAnalyticsSample] {
        let fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .forward)]
        )
        let sessions = try context.fetch(fd)

        return sessions.compactMap { session in
            if let window, !window.contains(session.startedAt) {
                return nil
            }

            let completedExerciseCount = session.exercises.reduce(into: 0) { count, exercise in
                if exercise.orderedSetLogs.contains(where: \.completed) {
                    count += 1
                }
            }

            let segmentsPresent = Set(session.exercises.map(\.segment))

            let endedAt: Date?
            if let rawEndedAt = session.endedAt, rawEndedAt >= session.startedAt {
                endedAt = rawEndedAt
            } else {
                endedAt = nil
            }

            let durationSeconds = endedAt.map { max(0, Int($0.timeIntervalSince(session.startedAt))) }

            return SessionAnalyticsSample(
                id: session.id,
                startedAt: session.startedAt,
                endedAt: endedAt,
                wasCompleted: session.status == .completed,
                completedExerciseCount: completedExerciseCount,
                durationSeconds: durationSeconds,
                segmentsPresent: segmentsPresent
            )
        }
    }
}
