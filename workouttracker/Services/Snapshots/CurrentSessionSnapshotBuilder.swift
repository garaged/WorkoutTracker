import Foundation
import SwiftData

@MainActor
struct CurrentSessionSnapshotBuilder {
    private let calendar: Calendar
        private let sessionResumePlanner: SessionResumePlanner
        private let systemIntegrationRouteResolver: SystemIntegrationRouteResolver
        private let trackedActivityRecorder: TrackedActivityRecorder

        init(
            calendar: Calendar,
            sessionResumePlanner: SessionResumePlanner,
            systemIntegrationRouteResolver: SystemIntegrationRouteResolver,
            trackedActivityRecorder: TrackedActivityRecorder
        ) {
            self.calendar = calendar
            self.sessionResumePlanner = sessionResumePlanner
            self.systemIntegrationRouteResolver = systemIntegrationRouteResolver
            self.trackedActivityRecorder = trackedActivityRecorder
        }

        init() {
            self.calendar = .current
            self.sessionResumePlanner = SessionResumePlanner()
            self.systemIntegrationRouteResolver = SystemIntegrationRouteResolver()
            self.trackedActivityRecorder = TrackedActivityRecorder()
        }

    @MainActor
    func build(context: ModelContext) -> CurrentSessionSnapshot {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        return build(sessions: sessions, activities: activities)
    }

    @MainActor
    func buildWidgetSnapshot(context: ModelContext) -> WidgetExternalSnapshot {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        let trackedActivitySessions = (try? context.fetch(FetchDescriptor<TrackedActivitySession>())) ?? []
        let routines = (try? context.fetch(FetchDescriptor<WorkoutRoutine>())) ?? []
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        let currentSession = buildWidgetCurrentSession(
            sessions: sessions,
            activities: activities,
            trackedActivitySessions: trackedActivitySessions
        )

        let progressSummary = (try? ProgressSummaryService(calendar: calendar).summarize(weeksBack: 12, context: context))
        let workoutsThisWeek = progressSummary?.weeks.last?.workoutsCompleted ?? 0

        return makeWidgetSnapshot(
            currentSession: currentSession,
            currentStreakDays: progressSummary?.currentStreakDays ?? 0,
            longestStreakDays: progressSummary?.longestStreakDays ?? 0,
            workoutsThisWeek: workoutsThisWeek,
            validateRoutes: true,
            sessions: sessions,
            trackedActivitySessions: trackedActivitySessions,
            routines: routines,
            activitiesByID: activitiesByID
        )
    }

    @MainActor
    func buildActiveSessionSurfaceSnapshot(
        context: ModelContext,
        preservedCurrentStreakDays: Int,
        preservedLongestStreakDays: Int,
        preservedWorkoutsThisWeek: Int
    ) -> WidgetExternalSnapshot {
        let currentSession = build(context: context)

        return makeWidgetSnapshot(
            currentSession: currentSession,
            currentStreakDays: preservedCurrentStreakDays,
            longestStreakDays: preservedLongestStreakDays,
            workoutsThisWeek: preservedWorkoutsThisWeek,
            validateRoutes: false,
            sessions: [],
            trackedActivitySessions: [],
            routines: [],
            activitiesByID: [:]
        )
    }

    @MainActor
    func buildWidgetActiveSessionSnapshot(
        context: ModelContext,
        preservedCurrentStreakDays: Int,
        preservedLongestStreakDays: Int,
        preservedWorkoutsThisWeek: Int
    ) -> WidgetExternalSnapshot {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        let trackedActivitySessions = (try? context.fetch(FetchDescriptor<TrackedActivitySession>())) ?? []

        let currentSession = buildWidgetCurrentSession(
            sessions: sessions,
            activities: activities,
            trackedActivitySessions: trackedActivitySessions
        )

        return makeWidgetSnapshot(
            currentSession: currentSession,
            currentStreakDays: preservedCurrentStreakDays,
            longestStreakDays: preservedLongestStreakDays,
            workoutsThisWeek: preservedWorkoutsThisWeek,
            validateRoutes: false,
            sessions: [],
            trackedActivitySessions: [],
            routines: [],
            activitiesByID: [:]
        )
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


    @MainActor
    private func buildWidgetCurrentSession(
        sessions: [WorkoutSession],
        activities: [Activity],
        trackedActivitySessions: [TrackedActivitySession]
    ) -> CurrentSessionSnapshot {
        let strengthSnapshot = build(sessions: sessions, activities: activities)
        if strengthSnapshot.sessionID != nil {
            return strengthSnapshot
        }

        guard let trackedSession = preferredWidgetTrackedActivitySession(from: trackedActivitySessions) else {
            return .empty
        }

        let liveTotals = trackedActivityRecorder.liveTotals(for: trackedSession)
        let subtitle = trackedSession.environment == .unspecified ? nil : trackedSession.environment.displayName
        let launchRoute: AppRoute = .trackedActivity(sessionID: trackedSession.id)

        return CurrentSessionSnapshot(
            sessionID: trackedSession.id,
            sessionTitle: trackedSession.activityKind.displayName,
            currentExerciseName: subtitle,
            currentSetIndex: nil,
            totalSets: nil,
            elapsedSeconds: liveTotals.elapsedDuration,
            restState: .inactive,
            restSeconds: nil,
            isResumable: trackedSession.lifecycleState == .inProgress || trackedSession.lifecycleState == .paused,
            isFinishable: trackedSession.lifecycleState == .inProgress || trackedSession.lifecycleState == .paused,
            openRoute: launchRoute,
            resumeRoute: launchRoute,
            restRoute: nil
        )
    }

    private func preferredWidgetTrackedActivitySession(
        from trackedActivitySessions: [TrackedActivitySession]
    ) -> TrackedActivitySession? {
        trackedActivitySessions
            .filter { $0.lifecycleState == .inProgress || $0.lifecycleState == .paused }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.id.uuidString > rhs.id.uuidString
            }
            .first
    }

    private func widgetRestState(for state: CurrentSessionSnapshot.RestState) -> WidgetExternalSnapshot.ActiveSession.RestState {
        switch state {
        case .inactive: .inactive
        case .running: .running
        case .overdue: .overdue
        }
    }

    private func makeWidgetSnapshot(
        currentSession: CurrentSessionSnapshot,
        currentStreakDays: Int,
        longestStreakDays: Int,
        workoutsThisWeek: Int,
        validateRoutes: Bool,
        sessions: [WorkoutSession],
        trackedActivitySessions: [TrackedActivitySession],
        routines: [WorkoutRoutine],
        activitiesByID: [UUID: Activity]
    ) -> WidgetExternalSnapshot {
        let activeSession = activeSessionPayload(
            from: currentSession,
            validateRoutes: validateRoutes,
            sessions: sessions,
            trackedActivitySessions: trackedActivitySessions,
            routines: routines,
            activitiesByID: activitiesByID
        )

        return WidgetExternalSnapshot(
            generatedAt: Date(),
            activeSession: activeSession,
            streak: .init(
                currentStreakDays: currentStreakDays,
                longestStreakDays: longestStreakDays,
                workoutsThisWeek: workoutsThisWeek
            ),
            schemaVersion: WidgetExternalSnapshot.currentSchemaVersion
        )
    }

    private func activeSessionPayload(
        from currentSession: CurrentSessionSnapshot,
        validateRoutes: Bool,
        sessions: [WorkoutSession],
        trackedActivitySessions: [TrackedActivitySession],
        routines: [WorkoutRoutine],
        activitiesByID: [UUID: Activity]
    ) -> WidgetExternalSnapshot.ActiveSession? {
        guard let sessionID = currentSession.sessionID else { return nil }

        let openRouteURL = routeURLString(
            for: currentSession.openRoute,
            expectedSessionID: sessionID,
            validateRoute: validateRoutes,
            sessions: sessions,
            trackedActivitySessions: trackedActivitySessions,
            routines: routines,
            activitiesByID: activitiesByID
        )
        guard let openRouteURL else { return nil }

        let resumeRouteURL = routeURLString(
            for: currentSession.resumeRoute,
            expectedSessionID: sessionID,
            validateRoute: validateRoutes,
            sessions: sessions,
            trackedActivitySessions: trackedActivitySessions,
            routines: routines,
            activitiesByID: activitiesByID
        )
        let restRouteURL = routeURLString(
            for: currentSession.restRoute,
            expectedSessionID: sessionID,
            validateRoute: validateRoutes,
            sessions: sessions,
            trackedActivitySessions: trackedActivitySessions,
            routines: routines,
            activitiesByID: activitiesByID
        )

        return WidgetExternalSnapshot.ActiveSession(
            sessionID: sessionID,
            title: currentSession.sessionTitle,
            currentExerciseName: currentSession.currentExerciseName,
            currentSetIndex: currentSession.currentSetIndex,
            totalSets: currentSession.totalSets,
            elapsedSeconds: Int(max(0, currentSession.elapsedSeconds ?? 0).rounded()),
            restState: widgetRestState(for: currentSession.restState),
            restSeconds: currentSession.restSeconds,
            isResumable: resumeRouteURL != nil,
            isFinishable: currentSession.isFinishable,
            openRouteURL: openRouteURL,
            resumeRouteURL: resumeRouteURL,
            restRouteURL: restRouteURL
        )
    }

    private func routeURLString(
        for route: AppRoute?,
        expectedSessionID: UUID,
        validateRoute: Bool,
        sessions: [WorkoutSession],
        trackedActivitySessions: [TrackedActivitySession],
        routines: [WorkoutRoutine],
        activitiesByID: [UUID: Activity]
    ) -> String? {
        guard validateRoute else {
            guard let route else { return nil }
            return urlString(for: route)
        }

        return validatedURLString(
            for: route,
            expectedSessionID: expectedSessionID,
            sessions: sessions,
            trackedActivitySessions: trackedActivitySessions,
            routines: routines,
            activitiesByID: activitiesByID
        )
    }

    private func validatedURLString(
        for route: AppRoute?,
        expectedSessionID: UUID,
        sessions: [WorkoutSession],
        trackedActivitySessions: [TrackedActivitySession],
        routines: [WorkoutRoutine],
        activitiesByID: [UUID: Activity]
    ) -> String? {
        guard let route,
              let rawValue = urlString(for: route),
              let url = URL(string: rawValue) else {
            return nil
        }

        let resolution = systemIntegrationRouteResolver.resolve(
            url: url,
            sessions: sessions,
            trackedActivitySessions: trackedActivitySessions,
            routines: routines,
            activitiesByID: activitiesByID
        )

        guard case .open(let resolvedRoute) = resolution,
              resolvedRoute == route,
              routeBelongsToSession(resolvedRoute, sessionID: expectedSessionID) else {
            return nil
        }

        return rawValue
    }

    private func routeBelongsToSession(_ route: AppRoute, sessionID: UUID) -> Bool {
        switch route {
        case .home:
            return true
        case .session(let resolvedSessionID):
            return resolvedSessionID == sessionID
        case .trackedActivity(let resolvedSessionID):
            return resolvedSessionID == sessionID
        case .sessionExercise(let resolvedSessionID, _):
            return resolvedSessionID == sessionID
        case .sessionRest(let resolvedSessionID):
            return resolvedSessionID == sessionID
        default:
            return false
        }
    }

    private func urlString(for route: AppRoute?) -> String? {
        guard let route else { return nil }

        switch route {
        case .home:
            return "workouttracker://home"
        case .session(let sessionID):
            return "workouttracker://session/\(sessionID.uuidString)"
        case .trackedActivity(let sessionID):
            return "workouttracker://tracked-activity/\(sessionID.uuidString)"
        case .sessionExercise(let sessionID, let exerciseID):
            return "workouttracker://session/\(sessionID.uuidString)/exercise/\(exerciseID.uuidString)"
        case .sessionRest(let sessionID):
            return "workouttracker://session/\(sessionID.uuidString)/rest"
        case .routine(let routineID):
            return "workouttracker://routine/\(routineID.uuidString)"
        case .calendarDay(let date):
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            return "workouttracker://calendar/\(formatter.string(from: date))"
        }
    }
}
