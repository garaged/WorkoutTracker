import Foundation
import SwiftData

@MainActor
enum WorkoutSessionStarter {

    static func startOrResumeSession(
        for activity: Activity,
        context: ModelContext,
        now: Date = Date()
    ) throws -> WorkoutSession {

        if let sid = activity.workoutSessionId {
            let desc = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sid })
            if let existing = try context.fetch(desc).first {
                return existing
            } else {
                activity.workoutSessionId = nil
            }
        }

        var templates: [WorkoutSessionFactory.ExerciseTemplate] = []
        var routineName: String? = nil
        var routineId: UUID? = activity.workoutRoutineId

        if let rid = routineId {
            let desc = FetchDescriptor<WorkoutRoutine>(predicate: #Predicate { $0.id == rid })
            if let routine = try context.fetch(desc).first {
                routineName = routine.name
                let executionSegments = WorkoutRoutineMapper.toExecutionSegments(routine: routine)
                templates = WorkoutRoutineMapper.toExerciseTemplates(executionSegments: executionSegments)
            } else {
                routineId = nil
            }
        }

        let session = WorkoutSessionFactory.makeSession(
            startedAt: now,
            linkedActivityId: activity.id,
            sourceRoutineId: routineId,
            sourceRoutineNameSnapshot: routineName,
            exercises: templates,
            prefillActualsFromTargets: true
        )

        context.insert(session)

        activity.kind = .workout
        activity.workoutSessionId = session.id

        try context.save()
        syncSystemIntegrations(context: context)
        return session
    }

    static func resumeForActiveLogging(
        _ session: WorkoutSession,
        context: ModelContext,
        now: Date = Date()
    ) throws {
        guard session.status == .inProgress, session.endedAt == nil else { return }
        session.resume(at: now)
        try context.save()
        syncSystemIntegrations(context: context)
    }

    static func keepForLater(
        _ session: WorkoutSession,
        context: ModelContext,
        now: Date = Date()
    ) throws {
        guard session.status == .inProgress, session.endedAt == nil else { return }
        session.dismissedStalePromptAt = now
        if !session.isPaused {
            session.pause(at: now)
        }
        try context.save()
        syncSystemIntegrations(context: context)
    }

    static func finishFromRecovery(
        _ session: WorkoutSession,
        context: ModelContext,
        now: Date = Date()
    ) throws {
        guard session.status == .inProgress, session.endedAt == nil else { return }
        if session.isPaused {
            session.resume(at: now)
        }
        session.endedAt = now
        session.status = .completed
        session.dismissedStalePromptAt = nil
        try context.save()
        syncSystemIntegrations(context: context)
    }

    static func discardUnfinishedSession(
        _ session: WorkoutSession,
        context: ModelContext,
        now: Date = Date()
    ) throws {
        guard session.status == .inProgress, session.endedAt == nil else { return }
        if session.isPaused {
            session.resume(at: now)
        }
        session.endedAt = now
        session.status = .abandoned
        session.dismissedStalePromptAt = nil
        try context.save()
        syncSystemIntegrations(context: context)
    }

    static func canMutateProgress(_ session: WorkoutSession) -> Bool {
        SessionLifecyclePolicy().canMutateProgress(session)
    }

    private static func syncSystemIntegrations(context: ModelContext) {
        WidgetRefreshCoordinator().refresh(context: context)

        guard #available(iOS 16.1, *) else { return }
        let snapshot = CurrentSessionSnapshotBuilder().buildWidgetSnapshot(context: context)

        Task { @MainActor in
            await LiveActivityCoordinator().sync(using: snapshot)
        }
    }
}
