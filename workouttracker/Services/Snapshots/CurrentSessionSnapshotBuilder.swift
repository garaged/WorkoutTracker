import Foundation
import SwiftData

struct CurrentSessionSnapshotBuilder {
    private let calendar: Calendar
    private let sessionResumePlanner: SessionResumePlanner
    private let systemIntegrationRouteResolver: SystemIntegrationRouteResolver

    init(
        calendar: Calendar = .current,
        sessionResumePlanner: SessionResumePlanner = SessionResumePlanner(),
        systemIntegrationRouteResolver: SystemIntegrationRouteResolver = SystemIntegrationRouteResolver()
    ) {
        self.calendar = calendar
        self.sessionResumePlanner = sessionResumePlanner
        self.systemIntegrationRouteResolver = systemIntegrationRouteResolver
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
        let routines = (try? context.fetch(FetchDescriptor<WorkoutRoutine>())) ?? []
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        let currentSession = build(sessions: sessions, activities: activities)

        let progressSummary = (try? ProgressSummaryService(calendar: calendar).summarize(weeksBack: 12, context: context))
        let workoutsThisWeek = progressSummary?.weeks.last?.workoutsCompleted ?? 0

        let activeSession: WidgetExternalSnapshot.ActiveSession?
        if let sessionID = currentSession.sessionID,
           let openRouteURL = validatedURLString(
                for: currentSession.openRoute,
                expectedSessionID: sessionID,
                sessions: sessions,
                routines: routines,
                activitiesByID: activitiesByID
           ) {
            let resumeRouteURL = validatedURLString(
                for: currentSession.resumeRoute,
                expectedSessionID: sessionID,
                sessions: sessions,
                routines: routines,
                activitiesByID: activitiesByID
            )
            let restRouteURL = validatedURLString(
                for: currentSession.restRoute,
                expectedSessionID: sessionID,
                sessions: sessions,
                routines: routines,
                activitiesByID: activitiesByID
            )

            activeSession = WidgetExternalSnapshot.ActiveSession(
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
        } else {
            activeSession = nil
        }

        return WidgetExternalSnapshot(
            generatedAt: Date(),
            activeSession: activeSession,
            streak: .init(
                currentStreakDays: progressSummary?.currentStreakDays ?? 0,
                longestStreakDays: progressSummary?.longestStreakDays ?? 0,
                workoutsThisWeek: workoutsThisWeek
            ),
            schemaVersion: WidgetExternalSnapshot.currentSchemaVersion
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

    private func widgetRestState(for state: CurrentSessionSnapshot.RestState) -> WidgetExternalSnapshot.ActiveSession.RestState {
        switch state {
        case .inactive: .inactive
        case .running: .running
        case .overdue: .overdue
        }
    }

    private func validatedURLString(
        for route: AppRoute?,
        expectedSessionID: UUID,
        sessions: [WorkoutSession],
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
        case .session(let resolvedSessionID):
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
