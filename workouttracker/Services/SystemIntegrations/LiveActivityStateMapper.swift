import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct LiveActivityStateMapper {
    struct MappedState {
        let attributes: ActiveWorkoutActivityAttributes
        let contentState: ActiveWorkoutActivityAttributes.ContentState
        let sessionID: UUID
        let staleDate: Date
    }

    func map(snapshot: WidgetExternalSnapshot) -> MappedState? {
        guard let activeSession = snapshot.activeSession else { return nil }
        return map(activeSession: activeSession, generatedAt: snapshot.generatedAt)
    }

    func map(
        activeSession: WidgetExternalSnapshot.ActiveSession,
        generatedAt: Date
    ) -> MappedState? {
        guard let openURLString = preferredOpenURLString(for: activeSession) else {
            return nil
        }

        let attributes = ActiveWorkoutActivityAttributes(
            sessionID: activeSession.sessionID,
            sessionTitle: activeSession.title ?? "Active Session"
        )

        let sessionStartDate = generatedAt.addingTimeInterval(TimeInterval(-max(0, activeSession.elapsedSeconds)))
        let restMode = mapRestMode(activeSession.restState)
        let restReferenceDate = deriveRestReferenceDate(
            restState: activeSession.restState,
            restSeconds: activeSession.restSeconds,
            generatedAt: generatedAt
        )

        let contentState = ActiveWorkoutActivityAttributes.ContentState(
            currentExerciseName: activeSession.currentExerciseName,
            currentSetIndex: activeSession.currentSetIndex,
            totalSets: activeSession.totalSets,
            stateGeneratedAt: generatedAt,
            sessionStartDate: sessionStartDate,
            restMode: restMode,
            restReferenceDate: restReferenceDate,
            openURLString: openURLString
        )

        return MappedState(
            attributes: attributes,
            contentState: contentState,
            sessionID: activeSession.sessionID,
            staleDate: deriveStaleDate(
                restState: activeSession.restState,
                generatedAt: generatedAt
            )
        )
    }

    private func preferredOpenURLString(for session: WidgetExternalSnapshot.ActiveSession) -> String? {
        if let restRouteURL = session.restRouteURL,
           session.restState != .inactive {
            return restRouteURL
        }

        if let resumeRouteURL = session.resumeRouteURL {
            return resumeRouteURL
        }

        if let openRouteURL = session.openRouteURL {
            return openRouteURL
        }

        return nil
    }

    private func mapRestMode(_ state: WidgetExternalSnapshot.ActiveSession.RestState) -> ActiveWorkoutActivityAttributes.ContentState.RestMode {
        switch state {
        case .inactive:
            return .inactive
        case .running:
            return .running
        case .overdue:
            return .overdue
        }
    }

    private func deriveRestReferenceDate(
        restState: WidgetExternalSnapshot.ActiveSession.RestState,
        restSeconds: Int?,
        generatedAt: Date
    ) -> Date? {
        guard let restSeconds else { return nil }

        switch restState {
        case .inactive:
            return nil
        case .running:
            return generatedAt.addingTimeInterval(TimeInterval(max(0, restSeconds)))
        case .overdue:
            return generatedAt.addingTimeInterval(TimeInterval(-abs(restSeconds)))
        }
    }

    private func deriveStaleDate(
        restState: WidgetExternalSnapshot.ActiveSession.RestState,
        generatedAt: Date
    ) -> Date {
        let freshnessWindow: TimeInterval
        switch restState {
        case .inactive:
            freshnessWindow = 2 * 60
        case .running, .overdue:
            freshnessWindow = 30
        }

        return generatedAt.addingTimeInterval(freshnessWindow)
    }
}
#endif
