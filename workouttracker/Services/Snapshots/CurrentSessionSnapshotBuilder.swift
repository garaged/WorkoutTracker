import Foundation
import SwiftData

struct CurrentSessionSnapshotBuilder {
    private let calendar: Calendar
    private let sessionResumePlanner: SessionResumePlanner

    init(
        calendar: Calendar = .current,
        sessionResumePlanner: SessionResumePlanner = SessionResumePlanner()
    ) {
        self.calendar = calendar
        self.sessionResumePlanner = sessionResumePlanner
    }

    @MainActor
    func build(context: ModelContext) -> CurrentSessionSnapshot {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        return build(sessions: sessions, activities: activities)
    }

    @MainActor
    func build(
        sessions: [WorkoutSession],
        activities: [Activity]
    ) -> CurrentSessionSnapshot {
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

        guard let session = sessionResumePlanner.currentActiveSession(
            from: sessions,
            activitiesByID: activitiesByID
        ) else {
            return .empty
        }

        let resumeTarget = sessionResumePlanner.currentResumeTarget(for: session)
        let openRoute = sessionResumePlanner.openRoute(for: session)
        let resumeRoute = sessionResumePlanner.resumeRoute(for: session)

        let targetExercise = resumeTarget.flatMap { target in
            session.exercises.first(where: { $0.id == target.exerciseID })
        }

        let orderedSets = targetExercise.map { exercise in
            exercise.setLogs.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        } ?? []

        let currentSetIndex = orderedSets.firstIndex(where: { $0.id == resumeTarget?.setID }).map { $0 + 1 }
        let elapsedSeconds = max(0, Date().timeIntervalSince(session.startedAt))

        let timer = SessionRestTimerController.shared
        let restState: CurrentSessionSnapshot.RestState
        let restSeconds: Int?
        let restRoute: AppRoute?

        if timer.hasConfiguredTimer {
            restSeconds = timer.displaySeconds
            restState = timer.displaySeconds < 0 ? .overdue : .running
            restRoute = .sessionRest(sessionID: session.id)
        } else {
            restSeconds = nil
            restState = .inactive
            restRoute = nil
        }

        return CurrentSessionSnapshot(
            sessionID: session.id,
            sessionTitle: session.sourceRoutineNameSnapshot,
            currentExerciseName: targetExercise?.exerciseNameSnapshot,
            currentSetIndex: currentSetIndex,
            totalSets: orderedSets.count,
            elapsedSeconds: elapsedSeconds,
            restState: restState,
            restSeconds: restSeconds,
            isResumable: resumeRoute != nil,
            isFinishable: session.status == .inProgress && session.endedAt == nil,
            openRoute: openRoute,
            resumeRoute: resumeRoute,
            restRoute: restRoute
        )
    }
}
