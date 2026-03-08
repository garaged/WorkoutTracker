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

        // If already linked, resume that session
        if let sid = activity.workoutSessionId {
            let desc = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sid })
            if let existing = try context.fetch(desc).first {
                return existing
            } else {
                // dangling link – clear it
                activity.workoutSessionId = nil
            }
        }

        // Build templates from routine if present
        var templates: [WorkoutSessionFactory.ExerciseTemplate] = []
        var routineName: String? = nil
        var routineId: UUID? = activity.workoutRoutineId

        if let rid = routineId {
            let desc = FetchDescriptor<WorkoutRoutine>(predicate: #Predicate { $0.id == rid })
            if let routine = try context.fetch(desc).first {
                routineName = routine.name
                templates = WorkoutRoutineMapper.toExerciseTemplates(routine: routine)
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

        // Link Activity <-> Session
        activity.kind = .workout
        activity.workoutSessionId = session.id

        try context.save()
        return session
    }
}
