import Foundation

struct SessionResumeTarget: Equatable {
    enum Reason: Equatable {
        case nextIncompleteSet
        case fallbackLastSet
        case noSets
    }

    let sessionID: UUID
    let exerciseID: UUID?
    let setID: UUID?
    let reason: Reason
}

struct SessionResumePlanner {
    private let calendar: Calendar
    private let continueNavigator: WorkoutContinueNavigator

    init(
        calendar: Calendar = .current,
        continueNavigator: WorkoutContinueNavigator = WorkoutContinueNavigator()
    ) {
        self.calendar = calendar
        self.continueNavigator = continueNavigator
    }

    func sortedActiveSessions(
        _ sessions: [WorkoutSession],
        activitiesByID: [UUID: Activity]
    ) -> [WorkoutSession] {
        sessions
            .filter { $0.status == .inProgress && $0.endedAt == nil }
            .sorted { lhs, rhs in
                let lhsOwningDay = calendar.startOfDay(for: owningDay(for: lhs, activitiesByID: activitiesByID))
                let rhsOwningDay = calendar.startOfDay(for: owningDay(for: rhs, activitiesByID: activitiesByID))

                let lhsToday = calendar.isDateInToday(lhsOwningDay)
                let rhsToday = calendar.isDateInToday(rhsOwningDay)

                if lhsToday != rhsToday {
                    return lhsToday && !rhsToday
                }

                if lhsOwningDay != rhsOwningDay {
                    return lhsOwningDay > rhsOwningDay
                }

                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt > rhs.startedAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    func preferredActiveSession(
        from sessions: [WorkoutSession],
        activitiesByID: [UUID: Activity]
    ) -> WorkoutSession? {
        sortedActiveSessions(sessions, activitiesByID: activitiesByID).first
    }

    func target(
        for session: WorkoutSession,
        activeExerciseID: UUID? = nil,
        activeSetID: UUID? = nil,
        visibleExercises: [WorkoutSessionExercise]? = nil
    ) -> SessionResumeTarget? {
        let orderedExercises = (visibleExercises ?? session.exercises)
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        guard !orderedExercises.isEmpty else {
            return SessionResumeTarget(
                sessionID: session.id,
                exerciseID: nil,
                setID: nil,
                reason: .noSets
            )
        }

        guard let targetSetID = continueNavigator.nextTargetSetID(
            exercises: orderedExercises,
            activeExerciseID: activeExerciseID,
            activeSetID: activeSetID
        ) else {
            return SessionResumeTarget(
                sessionID: session.id,
                exerciseID: nil,
                setID: nil,
                reason: .noSets
            )
        }

        guard let owningExercise = orderedExercises.first(where: { exercise in
            exercise.setLogs.contains(where: { $0.id == targetSetID })
        }) else {
            return nil
        }

        let orderedSets = owningExercise.setLogs.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let targetSet = orderedSets.first(where: { $0.id == targetSetID })

        return SessionResumeTarget(
            sessionID: session.id,
            exerciseID: owningExercise.id,
            setID: targetSetID,
            reason: (targetSet?.completed == false) ? .nextIncompleteSet : .fallbackLastSet
        )
    }

    func owningDay(
        for session: WorkoutSession,
        activitiesByID: [UUID: Activity]
    ) -> Date {
        guard let linkedID = session.linkedActivityId,
              let activity = activitiesByID[linkedID] else {
            return session.startedAt
        }
        return activity.startAt
    }
}
