import Foundation
import SwiftData

@MainActor
final class IntentActionCoordinator {
    enum Outcome: Equatable {
        case opened(AppRoute)
        case blocked(IntentPreconditionFailure)
    }

    private struct LoadedEnvironment {
        let sessions: [WorkoutSession]
        let routines: [WorkoutRoutine]
        let activitiesByID: [UUID: Activity]
    }

    private let now: () -> Date
    private let preconditions: IntentPreconditionEvaluator
    private let sessionResumePlanner: SessionResumePlanner
    private let systemIntegrationRouteResolver: SystemIntegrationRouteResolver

    init(
        now: @escaping () -> Date = Date.init,
        preconditions: IntentPreconditionEvaluator = IntentPreconditionEvaluator(),
        sessionResumePlanner: SessionResumePlanner = SessionResumePlanner(),
        systemIntegrationRouteResolver: SystemIntegrationRouteResolver = SystemIntegrationRouteResolver()
    ) {
        self.now = now
        self.preconditions = preconditions
        self.sessionResumePlanner = sessionResumePlanner
        self.systemIntegrationRouteResolver = systemIntegrationRouteResolver
    }

    func openCurrentSession() throws -> Outcome {
        let context = try IntentModelContextFactory.makeContext()
        return try openCurrentSession(context: context)
    }

    func resumeCurrentSession() throws -> Outcome {
        let context = try IntentModelContextFactory.makeContext()
        return try resumeCurrentSession(context: context)
    }

    func startRoutine(routineID: UUID) throws -> Outcome {
        let context = try IntentModelContextFactory.makeContext()
        return try startRoutine(routineID: routineID, context: context)
    }

    func finishCurrentSession(preferredSessionID: UUID? = nil) throws -> Outcome {
        let context = try IntentModelContextFactory.makeContext()
        return try finishCurrentSession(preferredSessionID: preferredSessionID, context: context)
    }

    func startRest() throws -> Outcome {
        let context = try IntentModelContextFactory.makeContext()
        return try startRest(context: context)
    }

    func openCurrentSession(context: ModelContext) throws -> Outcome {
        let loaded = try loadEnvironment(context: context)
        let gate = preconditions.resumableSession(from: loaded.sessions, activitiesByID: loaded.activitiesByID)

        guard let session = gate.value else {
            return .blocked(gate.failure ?? .noResumableSession)
        }

        return launchOutcome(
            for: sessionResumePlanner.openRoute(for: session),
            environment: loaded,
            blockedFailure: gate.failure ?? .launchTargetUnavailable
        )
    }

    func resumeCurrentSession(context: ModelContext) throws -> Outcome {
        let loaded = try loadEnvironment(context: context)
        let gate = preconditions.resumableSession(from: loaded.sessions, activitiesByID: loaded.activitiesByID)

        guard let session = gate.value else {
            return .blocked(gate.failure ?? .noResumableSession)
        }

        let route = sessionResumePlanner.resumeRoute(
            for: session,
            hasConfiguredRestTimer: SessionRestTimerController.shared.hasConfiguredTimer
        ) ?? .session(sessionID: session.id)

        return launchOutcome(
            for: route,
            environment: loaded,
            blockedFailure: gate.failure ?? .launchTargetUnavailable
        )
    }

    func startRoutine(routineID: UUID, context: ModelContext) throws -> Outcome {
        let routine = try fetchRoutine(id: routineID, context: context)
        let gate = preconditions.existingRoutine(routine)

        guard let routine = gate.value else {
            return .blocked(gate.failure ?? .routineNotFound)
        }

        let session = try WorkoutSessionStarter.startSession(
            from: routine,
            context: context,
            now: now()
        )

        let loaded = try loadEnvironment(context: context)
        return launchOutcome(
            for: .session(sessionID: session.id),
            environment: loaded,
            blockedFailure: .launchTargetUnavailable
        )
    }

    func finishCurrentSession(
        preferredSessionID: UUID? = nil,
        context: ModelContext
    ) throws -> Outcome {
        let loaded = try loadEnvironment(context: context)
        let gate = preconditions.finishableSession(
            preferredSessionID: preferredSessionID,
            from: loaded.sessions,
            activitiesByID: loaded.activitiesByID
        )

        guard let session = gate.value else {
            return .blocked(gate.failure ?? .noFinishableSession)
        }

        try WorkoutSessionStarter.finishSession(
            session,
            context: context,
            now: now()
        )

        return .opened(.home)
    }

    func startRest(context: ModelContext) throws -> Outcome {
        let loaded = try loadEnvironment(context: context)
        let gate = preconditions.restCapableSession(
            from: loaded.sessions,
            activitiesByID: loaded.activitiesByID,
            hasConfiguredRestTimer: SessionRestTimerController.shared.hasConfiguredTimer
        )

        guard let session = gate.value else {
            return .blocked(gate.failure ?? .noRestCapableContext)
        }

        return launchOutcome(
            for: .sessionRest(sessionID: session.id),
            environment: loaded,
            blockedFailure: gate.failure ?? .launchTargetUnavailable
        )
    }

    private func launchOutcome(
        for preferredRoute: AppRoute,
        environment: LoadedEnvironment,
        blockedFailure: IntentPreconditionFailure
    ) -> Outcome {
        guard let url = IntentLaunchBridge.url(for: preferredRoute) else {
            return .blocked(blockedFailure)
        }

        let resolution = systemIntegrationRouteResolver.resolve(
            url: url,
            sessions: environment.sessions,
            routines: environment.routines,
            activitiesByID: environment.activitiesByID
        )

        guard let route = resolution.route else {
            return .blocked(blockedFailure)
        }

        return .opened(route)
    }

    private func loadEnvironment(context: ModelContext) throws -> LoadedEnvironment {
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let routines = try context.fetch(FetchDescriptor<WorkoutRoutine>())
        let activities = try context.fetch(FetchDescriptor<Activity>())
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        return LoadedEnvironment(
            sessions: sessions,
            routines: routines,
            activitiesByID: activitiesByID
        )
    }

    private func fetchRoutine(id: UUID, context: ModelContext) throws -> WorkoutRoutine? {
        let wantedID = id
        let predicate = #Predicate<WorkoutRoutine> { routine in
            routine.id == wantedID
        }
        var descriptor = FetchDescriptor<WorkoutRoutine>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
