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

        let orderedSets = orderedExercises.flatMap(orderedSets(for:))

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
            let sets = entry.exercises.flatMap(orderedSets(for:))

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
        let groupedExercises = groupedCurrentSessionExercises(from: exercises)
        let exerciseIDs = groupedExercises.map(\.exerciseID)
        let cutoff = session.endedAt ?? session.startedAt
        let historyIndex = fetchHistoricalCompletedSetsIndex(
            exerciseIDs: exerciseIDs,
            excludingSessionID: session.id,
            before: cutoff,
            context: context
        )

        var items: [WorkoutSessionSummaryViewData.PRItem] = []
        var seen: Set<String> = []

        for exercise in groupedExercises {
            guard let previousCompleted = historyIndex[exercise.exerciseID], !previousCompleted.isEmpty else {
                continue
            }

            for set in exercise.completedSets {
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
                    let key = "\(exercise.title)|\(detail)"
                    guard seen.insert(key).inserted else { continue }

                    items.append(
                        WorkoutSessionSummaryViewData.PRItem(
                            id: key,
                            title: exercise.title,
                            detail: detail
                        )
                    )
                }
            }
        }

        return items
    }

    private func orderedSets(for exercise: WorkoutSessionExercise) -> [WorkoutSetLog] {
        exercise.setLogs.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private struct CurrentSessionExerciseGroup {
        let exerciseID: UUID
        let title: String
        var completedSets: [WorkoutSetLog]
    }

    private func groupedCurrentSessionExercises(
        from exercises: [WorkoutSessionExercise]
    ) -> [CurrentSessionExerciseGroup] {
        var groups: [CurrentSessionExerciseGroup] = []
        var indexByExerciseID: [UUID: Int] = [:]

        for exercise in exercises {
            let completedSets = orderedSets(for: exercise).filter(\.completed)
            guard !completedSets.isEmpty else { continue }

            if let index = indexByExerciseID[exercise.exerciseId] {
                groups[index].completedSets.append(contentsOf: completedSets)
            } else {
                indexByExerciseID[exercise.exerciseId] = groups.count
                groups.append(
                    CurrentSessionExerciseGroup(
                        exerciseID: exercise.exerciseId,
                        title: exercise.exerciseNameSnapshot,
                        completedSets: completedSets
                    )
                )
            }
        }

        return groups
    }

    private func fetchHistoricalCompletedSetsIndex(
        exerciseIDs: [UUID],
        excludingSessionID: UUID,
        before cutoff: Date,
        context: ModelContext
    ) -> [UUID: [CoachSuggestionService.CompletedSet]] {
        guard !exerciseIDs.isEmpty else { return [:] }

        let exerciseIDSet = Set(exerciseIDs)

        do {
            let descriptor = FetchDescriptor<WorkoutSetLog>(
                predicate: #Predicate<WorkoutSetLog> { set in
                    set.completed == true
                },
                sortBy: [SortDescriptor(\WorkoutSetLog.completedAt, order: .forward)]
            )

            let allCompletedSets = try context.fetch(descriptor)
            var grouped: [UUID: [CoachSuggestionService.CompletedSet]] = [:]

            for set in allCompletedSets {
                guard let completedAt = set.completedAt, completedAt < cutoff else { continue }
                guard set.sessionExercise?.session?.id != excludingSessionID else { continue }
                guard let exerciseID = set.sessionExercise?.exerciseId, exerciseIDSet.contains(exerciseID) else { continue }

                grouped[exerciseID, default: []].append(
                    CoachSuggestionService.CompletedSet(
                        weight: set.weight,
                        reps: set.reps,
                        weightUnitRaw: set.weightUnit.rawValue,
                        rpe: set.rpe
                    )
                )
            }

            return grouped
        } catch {
            return [:]
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
