import Foundation
import SwiftData

@MainActor
struct WorkoutSessionSummaryBuilder {
    private let coachService = CoachSuggestionService()

    func buildViewData(
        for session: WorkoutSession,
        context: ModelContext
    ) -> WorkoutSessionSummaryViewData {
        let orderedExercises = session.exercises.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        let orderedSets = orderedExercises.flatMap { exercise in
            exercise.setLogs.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }

        let completedSets = orderedSets.filter(\.completed).count
        let totalSets = orderedSets.count
        let skippedSets = max(totalSets - completedSets, 0)

        let prItems = buildPRItems(for: session, exercises: orderedExercises, context: context)

        return WorkoutSessionSummaryViewData(
            titleText: sessionTitle(for: session),
            dateText: formatDate(session.endedAt ?? session.startedAt),
            overallStatusText: overallStatus(
                session: session,
                completedSets: completedSets,
                totalSets: totalSets
            ),
            completedSetsText: "\(completedSets)",
            skippedSetsText: "\(skippedSets)",
            elapsedText: elapsedText(for: session),
            endedText: session.endedAt.map(formatTimestamp),
            prSummaryText: prItems.isEmpty ? "No personal records this session." : "",
            prItems: prItems,
            segmentRows: buildSegmentRows(from: orderedExercises),
            honestyFootnoteText: honestyFootnote(
                completedSets: completedSets,
                totalSets: totalSets,
                session: session
            )
        )
    }

    private func sessionTitle(for session: WorkoutSession) -> String {
        let trimmed = (session.sourceRoutineNameSnapshot ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Workout summary" : trimmed
    }

    private func overallStatus(
        session: WorkoutSession,
        completedSets: Int,
        totalSets: Int
    ) -> String {
        if session.status == .abandoned {
            return "Ended early"
        }

        guard totalSets > 0 else { return "Completed" }
        if completedSets == totalSets { return "Completed" }
        if completedSets == 0 { return "Ended early" }
        return "Partially completed"
    }

    private func elapsedText(for session: WorkoutSession) -> String {
        let seconds = session.elapsedSeconds()
        guard seconds > 0 else { return "Unavailable" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return minutes > 0 ? "\(hours) hr \(minutes) min" : "\(hours) hr"
        }

        if minutes > 0 {
            return "\(minutes) min"
        }

        return "< 1 min"
    }

    private func honestyFootnote(
        completedSets: Int,
        totalSets: Int,
        session: WorkoutSession
    ) -> String? {
        if totalSets == 0 {
            return "No set data was recorded for this session."
        }

        if completedSets == 0 {
            return "This session ended before much data was recorded."
        }

        if completedSets < totalSets, session.status != .abandoned {
            return "This session was finished with planned work still remaining."
        }

        return nil
    }

    private func buildSegmentRows(
        from exercises: [WorkoutSessionExercise]
    ) -> [WorkoutSessionSummaryViewData.SegmentRow] {
        var grouped: [(segment: WorkoutExerciseSegment, exercises: [WorkoutSessionExercise])] = []

        for exercise in exercises {
            if let idx = grouped.firstIndex(where: { $0.segment == exercise.segment }) {
                grouped[idx].exercises.append(exercise)
            } else {
                grouped.append((segment: exercise.segment, exercises: [exercise]))
            }
        }

        return grouped.map { entry in
            let sets = entry.exercises.flatMap { exercise in
                exercise.setLogs.sorted { lhs, rhs in
                    if lhs.order != rhs.order { return lhs.order < rhs.order }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
            }

            let total = sets.count
            let completed = sets.filter(\.completed).count
            let skipped = max(total - completed, 0)

            return WorkoutSessionSummaryViewData.SegmentRow(
                id: segmentID(for: entry.segment),
                title: segmentTitle(for: entry.segment),
                valueText: "\(completed) completed • \(skipped) skipped",
                statusText: segmentStatusText(completed: completed, total: total)
            )
        }
    }

    private func buildPRItems(
        for session: WorkoutSession,
        exercises: [WorkoutSessionExercise],
        context: ModelContext
    ) -> [WorkoutSessionSummaryViewData.PRItem] {
        var items: [WorkoutSessionSummaryViewData.PRItem] = []
        var seen: Set<String> = []

        for exercise in exercises {
            let previous = fetchHistoricalCompletedSets(
                exerciseId: exercise.exerciseId,
                excludingSessionID: session.id,
                before: session.endedAt ?? session.startedAt,
                context: context
            )

            guard !previous.isEmpty else { continue }

            let previousCompleted = previous.map {
                CoachSuggestionService.CompletedSet(
                    weight: $0.weight,
                    reps: $0.reps,
                    weightUnitRaw: $0.weightUnit.rawValue,
                    rpe: $0.rpe
                )
            }

            let orderedSets = exercise.setLogs.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            for set in orderedSets where set.completed {
                let current = CoachSuggestionService.CompletedSet(
                    weight: set.weight,
                    reps: set.reps,
                    weightUnitRaw: set.weightUnit.rawValue,
                    rpe: set.rpe
                )

                let achievements = coachService.prAchievements(
                    completed: current,
                    previous: previousCompleted
                )

                for achievement in achievements {
                    let detail = "\(achievement.kind.rawValue): \(achievement.valueText)"
                    let key = "\(exercise.exerciseNameSnapshot)|\(detail)"
                    guard seen.insert(key).inserted else { continue }

                    items.append(
                        WorkoutSessionSummaryViewData.PRItem(
                            id: key,
                            title: exercise.exerciseNameSnapshot,
                            detail: detail
                        )
                    )
                }
            }
        }

        return items
    }

    private func fetchHistoricalCompletedSets(
        exerciseId: UUID,
        excludingSessionID: UUID,
        before cutoff: Date,
        context: ModelContext
    ) -> [WorkoutSetLog] {
        let exId: UUID? = exerciseId

        do {
            let descriptor = FetchDescriptor<WorkoutSetLog>(
                predicate: #Predicate<WorkoutSetLog> { set in
                    set.completed == true &&
                    set.sessionExercise?.exerciseId == exId
                },
                sortBy: [SortDescriptor(\WorkoutSetLog.completedAt, order: .forward)]
            )

            return try context.fetch(descriptor).filter { set in
                guard set.sessionExercise?.session?.id != excludingSessionID else { return false }
                guard let completedAt = set.completedAt else { return false }
                return completedAt < cutoff
            }
        } catch {
            return []
        }
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func formatTimestamp(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }

    private func segmentTitle(for kind: WorkoutExerciseSegment) -> String {
        switch kind {
        case .warmUp:
            return "Warm-up"
        case .main:
            return "Workout"
        case .coolDown:
            return "Cool-down"
        }
    }

    private func segmentID(for kind: WorkoutExerciseSegment) -> String {
        switch kind {
        case .warmUp:
            return "warmUp"
        case .main:
            return "main"
        case .coolDown:
            return "coolDown"
        }
    }

    private func segmentStatusText(completed: Int, total: Int) -> String? {
        guard total > 0 else { return nil }
        if completed == total { return "Completed" }
        if completed == 0 { return "Not completed" }
        return "Partial"
    }
}
