import XCTest
@testable import workouttracker

final class SystemIntegrationRouteResolverTests: XCTestCase {
    private let resolver = SystemIntegrationRouteResolver(
        routeResolver: RouteResolver(calendar: Calendar(identifier: .gregorian)),
        sessionResumePlanner: SessionResumePlanner(calendar: Calendar(identifier: .gregorian))
    )

    func test_resolve_missingSession_fallsBackToPreferredActiveSession() {
        let olderSession = WorkoutSession(startedAt: Date(timeIntervalSince1970: 100))
        olderSession.status = .inProgress
        olderSession.endedAt = nil

        let newerSession = WorkoutSession(startedAt: Date(timeIntervalSince1970: 200))
        newerSession.status = .inProgress
        newerSession.endedAt = nil

        let resolution = resolver.resolve(
            payload: .session(.init(sessionID: UUID(), target: .session)),
            sessions: [olderSession, newerSession], trackedActivitySessions: [],
            routines: [],
            activitiesByID: [:]
        )

        XCTAssertEqual(
            resolution,
            .fallback(.session(sessionID: newerSession.id), reason: .targetSessionMissing)
        )
    }

    func test_resolve_missingSession_fallsBackToHomeWhenNoActiveSessionExists() {
        let completedSession = WorkoutSession(startedAt: Date(timeIntervalSince1970: 100))
        completedSession.status = .completed
        completedSession.endedAt = Date(timeIntervalSince1970: 300)

        let resolution = resolver.resolve(
            payload: .session(.init(sessionID: UUID(), target: .session)),
            sessions: [completedSession], trackedActivitySessions: [],
            routines: [],
            activitiesByID: [:]
        )

        XCTAssertEqual(
            resolution,
            .fallback(.home, reason: .targetSessionMissing)
        )
    }

    func test_resolve_finishedSession_fallsBackToPreferredActiveSession() {
        let finishedSession = WorkoutSession(startedAt: Date(timeIntervalSince1970: 100))
        finishedSession.status = .completed
        finishedSession.endedAt = Date(timeIntervalSince1970: 150)

        let activeSession = WorkoutSession(startedAt: Date(timeIntervalSince1970: 200))
        activeSession.status = .inProgress
        activeSession.endedAt = nil

        let resolution = resolver.resolve(
            payload: .session(.init(sessionID: finishedSession.id, target: .session)),
            sessions: [finishedSession, activeSession], trackedActivitySessions: [],
            routines: [],
            activitiesByID: [:]
        )

        XCTAssertEqual(
            resolution,
            .fallback(.session(sessionID: activeSession.id), reason: .targetSessionNotLaunchable)
        )
    }

    func test_resolve_missingExercise_fallsBackToSessionRoot() {
        let session = WorkoutSession(startedAt: Date(timeIntervalSince1970: 100))
        session.status = .inProgress
        session.endedAt = nil

        let resolution = resolver.resolve(
            payload: .session(.init(sessionID: session.id, target: .exercise(UUID()))),
            sessions: [session], trackedActivitySessions: [],
            routines: [],
            activitiesByID: [:]
        )

        XCTAssertEqual(
            resolution,
            .fallback(.session(sessionID: session.id), reason: .targetExerciseMissing)
        )
    }

    func test_resolve_validSessionExercise_opensExactRoute() {
        let session = WorkoutSession(startedAt: Date(timeIntervalSince1970: 100))
        session.status = .inProgress
        session.endedAt = nil

        let exercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Bench Press"
        )
        session.exercises = [exercise]

        let resolution = resolver.resolve(
            payload: .session(.init(sessionID: session.id, target: .exercise(exercise.id))),
            sessions: [session], trackedActivitySessions: [],
            routines: [],
            activitiesByID: [:]
        )

        XCTAssertEqual(
            resolution,
            .open(.sessionExercise(sessionID: session.id, exerciseID: exercise.id))
        )
    }

    func test_resolve_missingRoutine_fallsBackToHome() {
        let resolution = resolver.resolve(
            payload: .routine(.init(routineID: UUID())),
            sessions: [], trackedActivitySessions: [],
            routines: [],
            activitiesByID: [:]
        )

        XCTAssertEqual(
            resolution,
            .fallback(.home, reason: .targetRoutineMissing)
        )
    }
}

#if canImport(ActivityKit)
@available(iOS 16.1, *)
final class LiveActivityStateMapperTests: XCTestCase {
    private let mapper = LiveActivityStateMapper()

    func test_map_runningRestWithFutureEnd_preservesRunningModeAndReferenceDate() {
        let generatedAt = Date(timeIntervalSinceReferenceDate: 10_000)
        let sessionID = UUID()
        let snapshot = WidgetExternalSnapshot.ActiveSession(
            sessionID: sessionID,
            title: "Push Day",
            currentExerciseName: "Bench Press",
            currentSetIndex: 2,
            totalSets: 5,
            elapsedSeconds: 600,
            restState: .running,
            restSeconds: 45,
            isResumable: true,
            isFinishable: true,
            openRouteURL: "workouttracker://session",
            resumeRouteURL: "workouttracker://session/resume",
            restRouteURL: "workouttracker://session/rest"
        )

        let mapped = mapper.map(activeSession: snapshot, generatedAt: generatedAt)

        XCTAssertEqual(mapped?.sessionID, sessionID)
        XCTAssertEqual(mapped?.contentState.restMode, .running)
        XCTAssertEqual(mapped?.contentState.restReferenceDate, generatedAt.addingTimeInterval(45))
        XCTAssertEqual(mapped?.contentState.stateGeneratedAt, generatedAt)
    }

    func test_map_runningRestAtZero_promotesToOverdue() {
        let generatedAt = Date(timeIntervalSinceReferenceDate: 10_000)
        let snapshot = WidgetExternalSnapshot.ActiveSession(
            sessionID: UUID(),
            title: "Push Day",
            currentExerciseName: "Bench Press",
            currentSetIndex: 2,
            totalSets: 5,
            elapsedSeconds: 600,
            restState: .running,
            restSeconds: 0,
            isResumable: true,
            isFinishable: true,
            openRouteURL: "workouttracker://session",
            resumeRouteURL: "workouttracker://session/resume",
            restRouteURL: "workouttracker://session/rest"
        )

        let mapped = mapper.map(activeSession: snapshot, generatedAt: generatedAt)

        XCTAssertEqual(mapped?.contentState.restMode, .overdue)
        XCTAssertEqual(mapped?.contentState.restReferenceDate, generatedAt)
    }

    func test_map_overdueRest_preservesPastReferenceDateForSignedCountUp() {
        let generatedAt = Date(timeIntervalSinceReferenceDate: 10_000)
        let snapshot = WidgetExternalSnapshot.ActiveSession(
            sessionID: UUID(),
            title: "Push Day",
            currentExerciseName: "Bench Press",
            currentSetIndex: 2,
            totalSets: 5,
            elapsedSeconds: 600,
            restState: .overdue,
            restSeconds: -12,
            isResumable: true,
            isFinishable: true,
            openRouteURL: "workouttracker://session",
            resumeRouteURL: "workouttracker://session/resume",
            restRouteURL: "workouttracker://session/rest"
        )

        let mapped = mapper.map(activeSession: snapshot, generatedAt: generatedAt)

        XCTAssertEqual(mapped?.contentState.restMode, .overdue)
        XCTAssertEqual(mapped?.contentState.restReferenceDate, generatedAt.addingTimeInterval(-12))
    }
}
#endif
