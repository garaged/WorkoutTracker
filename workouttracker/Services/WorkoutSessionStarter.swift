// File: workouttracker/Services/WorkoutSessionStarter.swift
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
                // Normalize relationship ordering on resume too.
                existing.exercises.sort { $0.order < $1.order }
                for ex in existing.exercises {
                    ex.setLogs.sort { $0.order < $1.order }
                }
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

        // Important: SwiftData relationship arrays are not guaranteed to stay
        // in insertion order after save, so normalize before returning.
        session.exercises.sort { $0.order < $1.order }
        for ex in session.exercises {
            ex.setLogs.sort { $0.order < $1.order }
        }

        return session
    }
}
