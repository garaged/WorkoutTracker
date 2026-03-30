import Foundation
import SwiftData

@MainActor
final class IntentActionCoordinator {
    enum Outcome: Equatable {
        case opened(AppRoute)
        case blocked(IntentPreconditionFailure)
    }

    private let now: () -> Date
    private let preconditions: IntentPreconditionEvaluator
    private let sessionResumePlanner: SessionResumePlanner

    init(
        now: @escaping () -> Date = Date.init,
        preconditions: IntentPreconditionEvaluator = IntentPreconditionEvaluator(),
        sessionResumePlanner: SessionResumePlanner = SessionResumePlanner()
    ) {
        self.now = now
        self.preconditions = preconditions
        self.sessionResumePlanner = sessionResumePlanner
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
        let loaded = try loadSessionEnvironment(context: context)
        let gate = preconditions.resumableSession(from: loaded.sessions, activitiesByID: loaded.activitiesByID)

        guard let session = gate.value else {
            return .blocked(gate.failure ?? .noResumableSession)
        }

        return .opened(sessionResumePlanner.openRoute(for: session))
    }

    func resumeCurrentSession(context: ModelContext) throws -> Outcome {
        let loaded = try loadSessionEnvironment(context: context)
        let gate = preconditions.resumableSession(from: loaded.sessions, activitiesByID: loaded.activitiesByID)

        guard let session = gate.value else {
            return .blocked(gate.failure ?? .noResumableSession)
        }

        let route = sessionResumePlanner.resumeRoute(
            for: session,
            hasConfiguredRestTimer: SessionRestTimerController.shared.hasConfiguredTimer
        ) ?? .session(sessionID: session.id)

        return .opened(route)
    }

    func startRoutine(routineID: UUID, context: ModelContext) throws -> Outcome {
        let routine = try fetchRoutine(id: routineID, context: context)
        let gate = preconditions.existingRoutine(routine)

        guard let routine = gate.value else {
            return .blocked(gate.failure ?? .routineNotFound)
        }

        let templates = WorkoutRoutineMapper.toExerciseTemplates(routine: routine)
        let session = WorkoutSessionFactory.makeSession(
            startedAt: now(),
            linkedActivityId: nil,
            sourceRoutineId: routine.id,
            sourceRoutineNameSnapshot: routine.name,
            exercises: templates
        )

        context.insert(session)
        try context.save()
        WidgetRefreshCoordinator().refresh(context: context)

        return .opened(.session(sessionID: session.id))
    }

    func finishCurrentSession(
        preferredSessionID: UUID? = nil,
        context: ModelContext
    ) throws -> Outcome {
        let loaded = try loadSessionEnvironment(context: context)
        let gate = preconditions.finishableSession(
            preferredSessionID: preferredSessionID,
            from: loaded.sessions,
            activitiesByID: loaded.activitiesByID
        )

        guard let session = gate.value else {
            return .blocked(gate.failure ?? .noFinishableSession)
        }

        session.status = .completed
        session.endedAt = now()
        try context.save()
        WidgetRefreshCoordinator().refresh(context: context)

        return .opened(.home)
    }

    func startRest(context: ModelContext) throws -> Outcome {
        let loaded = try loadSessionEnvironment(context: context)
        let gate = preconditions.restCapableSession(
            from: loaded.sessions,
            activitiesByID: loaded.activitiesByID,
            hasConfiguredRestTimer: SessionRestTimerController.shared.hasConfiguredTimer
        )

        guard let session = gate.value else {
            return .blocked(gate.failure ?? .noRestCapableContext)
        }

        // PR2 foundation behavior: keep perform methods honest about whether a rest-capable
        // context exists, but route back into the canonical session-rest surface rather than
        // duplicating timer-configuration logic inside the intent layer.
        return .opened(.sessionRest(sessionID: session.id))
    }

    private func loadSessionEnvironment(context: ModelContext) throws -> (sessions: [WorkoutSession], activitiesByID: [UUID: Activity]) {
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let activities = try context.fetch(FetchDescriptor<Activity>())
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        return (sessions, activitiesByID)
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
