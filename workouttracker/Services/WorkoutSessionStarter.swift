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
    
    static func startSession(
        from routine: WorkoutRoutine,
        context: ModelContext,
        now: Date = Date()
    ) throws -> WorkoutSession {
        let executionSegments = WorkoutRoutineMapper.toExecutionSegments(routine: routine)
        let templates = WorkoutRoutineMapper.toExerciseTemplates(executionSegments: executionSegments)

        let session = WorkoutSessionFactory.makeSession(
            startedAt: now,
            linkedActivityId: nil,
            sourceRoutineId: routine.id,
            sourceRoutineNameSnapshot: routine.name,
            exercises: templates,
            prefillActualsFromTargets: true
        )

        context.insert(session)
        try context.save()
        syncSystemIntegrations(context: context)
        return session
    }
    
    static func finishSession(
        _ session: WorkoutSession,
        context: ModelContext,
        now: Date = Date()
    ) throws {
        try finishFromRecovery(session, context: context, now: now)
    }

    static func startSession(
        from routine: WorkoutRoutine,
        assignment: ProgramAssignment,
        program: TrainingProgram,
        weekIndex: Int,
        day: ProgramDay,
        context: ModelContext,
        now: Date = Date()
    ) throws -> WorkoutSession {
        let executionSegments = WorkoutRoutineMapper.toExecutionSegments(routine: routine)
        let templates = makeProgramExerciseTemplates(
            executionSegments: executionSegments,
            day: day
        )

        let session = WorkoutSessionFactory.makeSession(
            startedAt: now,
            linkedActivityId: nil,
            sourceRoutineId: routine.id,
            sourceRoutineNameSnapshot: routine.name,
            programContext: .init(
                assignmentId: assignment.id,
                programId: program.id,
                weekIndex: weekIndex,
                dayIndex: day.index
            ),
            exercises: templates,
            prefillActualsFromTargets: true
        )

        context.insert(session)
        try context.save()
        syncSystemIntegrations(context: context)
        return session
    }

    private static func makeProgramExerciseTemplates(
        executionSegments: [WorkoutRoutineMapper.ExecutionSegment],
        day: ProgramDay
    ) -> [WorkoutSessionFactory.ExerciseTemplate] {
        var templates = WorkoutRoutineMapper.toExerciseTemplates(executionSegments: executionSegments)
        var remainingPrescriptions = day.orderedPrescriptions

        for index in templates.indices {
            guard let matchIndex = remainingPrescriptions.firstIndex(where: { prescription in
                matches(template: templates[index], prescription: prescription)
            }) else {
                continue
            }

            let prescription = remainingPrescriptions.remove(at: matchIndex)
            templates[index].sourceProgramPrescriptionId = prescription.id

            let desiredSetCount = max(prescription.targetSets ?? templates[index].sets.count, 1)
            if desiredSetCount > templates[index].sets.count,
               let last = templates[index].sets.last {
                for extraIndex in templates[index].sets.count..<desiredSetCount {
                    var copy = last
                    copy.order = extraIndex
                    templates[index].sets.append(copy)
                }
            }

            for setIndex in templates[index].sets.indices {
                templates[index].sets[setIndex].order = setIndex
                if let targetReps = prescription.targetReps {
                    templates[index].sets[setIndex].targetReps = targetReps
                }
                if let targetWeight = prescription.targetWeight {
                    templates[index].sets[setIndex].targetWeight = targetWeight
                }
                if let weightUnit = prescription.weightUnit {
                    templates[index].sets[setIndex].targetWeightUnit = weightUnit
                }
                if let targetRPE = prescription.targetRPE {
                    templates[index].sets[setIndex].targetRPE = targetRPE
                }
                if let targetDurationSeconds = prescription.targetDurationSeconds {
                    templates[index].sets[setIndex].targetDurationSeconds = targetDurationSeconds
                }
                if let targetDistance = prescription.targetDistance {
                    templates[index].sets[setIndex].targetDistance = targetDistance
                }
            }
        }

        return templates
    }

    private static func matches(
        template: WorkoutSessionFactory.ExerciseTemplate,
        prescription: ProgramPrescription
    ) -> Bool {
        if let exerciseId = prescription.exerciseId {
            return template.exerciseId == exerciseId
        }

        if let snapshot = prescription.exerciseNameSnapshot?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !snapshot.isEmpty {
            return template.nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == snapshot
        }

        return false
    }
}
