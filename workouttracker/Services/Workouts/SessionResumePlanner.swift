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

    func currentActiveSession(
        from sessions: [WorkoutSession],
        activitiesByID: [UUID: Activity]
    ) -> WorkoutSession? {
        preferredActiveSession(from: sessions, activitiesByID: activitiesByID)
    }

    func currentResumeTarget(
        from sessions: [WorkoutSession],
        activitiesByID: [UUID: Activity]
    ) -> SessionResumeTarget? {
        guard let session = currentActiveSession(from: sessions, activitiesByID: activitiesByID) else {
            return nil
        }
        return currentResumeTarget(for: session)
    }

    func currentResumeTarget(for session: WorkoutSession) -> SessionResumeTarget? {
        target(for: session)
    }

    func openRoute(for session: WorkoutSession) -> AppRoute {
        .session(sessionID: session.id)
    }

    @MainActor
    func resumeRoute(
        for session: WorkoutSession,
        activeExerciseID: UUID? = nil,
        activeSetID: UUID? = nil,
        visibleExercises: [WorkoutSessionExercise]? = nil
    ) -> AppRoute? {
        resumeRoute(
            for: session,
            activeExerciseID: activeExerciseID,
            activeSetID: activeSetID,
            visibleExercises: visibleExercises,
            hasConfiguredRestTimer: SessionRestTimerController.shared.hasConfiguredTimer
        )
    }

    func resumeRoute(
        for session: WorkoutSession,
        activeExerciseID: UUID? = nil,
        activeSetID: UUID? = nil,
        visibleExercises: [WorkoutSessionExercise]? = nil,
        hasConfiguredRestTimer: Bool
    ) -> AppRoute? {
        guard session.status == .inProgress, session.endedAt == nil else {
            return nil
        }

        if hasConfiguredRestTimer {
            return .sessionRest(sessionID: session.id)
        }

        guard let target = target(
            for: session,
            activeExerciseID: activeExerciseID,
            activeSetID: activeSetID,
            visibleExercises: visibleExercises
        ) else {
            return .session(sessionID: session.id)
        }

        guard let exerciseID = target.exerciseID else {
            return .session(sessionID: session.id)
        }

        return .sessionExercise(sessionID: session.id, exerciseID: exerciseID)
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

    func targetSet(
        for session: WorkoutSession,
        activeExerciseID: UUID? = nil,
        activeSetID: UUID? = nil,
        visibleExercises: [WorkoutSessionExercise]? = nil
    ) -> WorkoutSetLog? {
        guard let target = target(
            for: session,
            activeExerciseID: activeExerciseID,
            activeSetID: activeSetID,
            visibleExercises: visibleExercises
        ) else {
            return nil
        }

        return targetSet(for: session, target: target, visibleExercises: visibleExercises)
    }

    func targetSet(
        for session: WorkoutSession,
        target: SessionResumeTarget,
        visibleExercises: [WorkoutSessionExercise]? = nil
    ) -> WorkoutSetLog? {
        guard let exerciseID = target.exerciseID,
              let setID = target.setID else {
            return nil
        }

        let exercises = visibleExercises ?? session.exercises
        guard let exercise = exercises.first(where: { $0.id == exerciseID }) else {
            return nil
        }

        return exercise.setLogs.first(where: { $0.id == setID })
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
