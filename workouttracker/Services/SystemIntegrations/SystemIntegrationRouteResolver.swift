import Foundation

struct SystemIntegrationRouteResolver {
    private let routeResolver: RouteResolver
    private let sessionResumePlanner: SessionResumePlanner

    init(
        routeResolver: RouteResolver = RouteResolver(),
        sessionResumePlanner: SessionResumePlanner = SessionResumePlanner()
    ) {
        self.routeResolver = routeResolver
        self.sessionResumePlanner = sessionResumePlanner
    }

    func resolve(
        url: URL,
        sessions: [WorkoutSession],
        trackedActivitySessions: [TrackedActivitySession],
        routines: [WorkoutRoutine],
        activitiesByID: [UUID: Activity]
    ) -> SystemIntegrationRouteResolution {
        guard let payload = routeResolver.payload(for: url) else {
            return .ignore(reason: .invalidURL)
        }

        return resolve(
            payload: payload,
            sessions: sessions,
            trackedActivitySessions: trackedActivitySessions,
            routines: routines,
            activitiesByID: activitiesByID
        )
    }

    func resolve(
        payload: RoutePayload,
        sessions: [WorkoutSession],
        trackedActivitySessions: [TrackedActivitySession],
        routines: [WorkoutRoutine],
        activitiesByID: [UUID: Activity]
    ) -> SystemIntegrationRouteResolution {
        switch payload {
        case .home, .calendarDay:
            if let route = routeResolver.route(for: payload, sessions: sessions, trackedActivitySessions: trackedActivitySessions, routines: routines) {
                return .open(route)
            }
            return .fallback(.home, reason: .invalidURL)

        case .routine(let payload):
            guard routines.contains(where: { $0.id == payload.routineID }) else {
                return .fallback(.home, reason: .targetRoutineMissing)
            }

            if let route = routeResolver.route(for: .routine(payload), sessions: sessions, trackedActivitySessions: trackedActivitySessions, routines: routines) {
                return .open(route)
            }

            return .fallback(.home, reason: .targetRoutineMissing)

        case .trackedActivity(let payload):
            guard let session = trackedActivitySessions.first(where: { $0.id == payload.sessionID }) else {
                return missingTrackedActivityFallback(reason: .targetSessionMissing, trackedActivitySessions: trackedActivitySessions)
            }

            guard isLaunchable(session) else {
                return missingTrackedActivityFallback(reason: .targetSessionNotLaunchable, trackedActivitySessions: trackedActivitySessions.filter { $0.id != payload.sessionID })
            }

            return .open(.trackedActivity(sessionID: session.id))

        case .session(let payload):
            guard let session = sessions.first(where: { $0.id == payload.sessionID }) else {
                return missingSessionFallback(
                    reason: .targetSessionMissing,
                    sessions: sessions,
                    activitiesByID: activitiesByID
                )
            }

            guard isLaunchable(session) else {
                return missingSessionFallback(
                    reason: .targetSessionNotLaunchable,
                    sessions: sessions,
                    activitiesByID: activitiesByID,
                    excluding: payload.sessionID
                )
            }

            switch payload.target {
            case .session, .rest:
                if let route = routeResolver.route(for: .session(payload), sessions: sessions, trackedActivitySessions: trackedActivitySessions, routines: routines) {
                    return .open(route)
                }
                return .fallback(.session(sessionID: session.id), reason: .targetSessionNotLaunchable)

            case .exercise(let exerciseID):
                guard session.exercises.contains(where: { $0.id == exerciseID }) else {
                    return .fallback(.session(sessionID: session.id), reason: .targetExerciseMissing)
                }

                if let route = routeResolver.route(for: .session(payload), sessions: sessions, trackedActivitySessions: trackedActivitySessions, routines: routines) {
                    return .open(route)
                }

                return .fallback(.session(sessionID: session.id), reason: .targetSessionNotLaunchable)
            }
        }
    }

    private func missingSessionFallback(
        reason: SystemIntegrationFallbackReason,
        sessions: [WorkoutSession],
        activitiesByID: [UUID: Activity],
        excluding excludedSessionID: UUID? = nil
    ) -> SystemIntegrationRouteResolution {
        let candidateSessions: [WorkoutSession]
        if let excludedSessionID {
            candidateSessions = sessions.filter { $0.id != excludedSessionID }
        } else {
            candidateSessions = sessions
        }

        guard let fallbackSession = sessionResumePlanner.currentActiveSession(
            from: candidateSessions,
            activitiesByID: activitiesByID
        ) else {
            let terminalReason: SystemIntegrationFallbackReason =
                reason == .targetSessionMissing ? .targetSessionMissing : .noActiveSession
            return .fallback(.home, reason: terminalReason)
        }

        return .fallback(.session(sessionID: fallbackSession.id), reason: reason)
    }

    private func missingTrackedActivityFallback(
        reason: SystemIntegrationFallbackReason,
        trackedActivitySessions: [TrackedActivitySession]
    ) -> SystemIntegrationRouteResolution {
        guard let fallback = trackedActivitySessions.first(where: { isLaunchable($0) }) else {
            let terminalReason: SystemIntegrationFallbackReason =
                reason == .targetSessionMissing ? .targetSessionMissing : .noActiveSession
            return .fallback(.home, reason: terminalReason)
        }

        return .fallback(.trackedActivity(sessionID: fallback.id), reason: reason)
    }

    private func isLaunchable(_ session: WorkoutSession) -> Bool {
        session.status == .inProgress && session.endedAt == nil
    }

    private func isLaunchable(_ session: TrackedActivitySession) -> Bool {
        session.lifecycleState == .inProgress || session.lifecycleState == .paused
    }
}
