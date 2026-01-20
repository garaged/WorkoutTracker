// File: Services/WorkoutSessionStarter.swift
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
                templates = exerciseTemplates(from: routine)
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

    private static func exerciseTemplates(from routine: WorkoutRoutine) -> [WorkoutSessionFactory.ExerciseTemplate] {
        let items = routine.items.sorted { $0.order < $1.order }

        return items.compactMap { item in
            guard let ex = item.exercise else { return nil }

            let setPlans = item.setPlans.sorted { $0.order < $1.order }
            let sets: [WorkoutSessionFactory.SetTemplate] = (setPlans.isEmpty ? [WorkoutSetPlan(order: 0, routineItem: item)] : setPlans)
                .enumerated()
                .map { idx, p in
                    WorkoutSessionFactory.SetTemplate(
                        order: idx,
                        targetReps: p.targetReps,
                        targetWeight: p.targetWeight,
                        targetWeightUnit: p.weightUnit,
                        targetRPE: p.targetRPE,
                        targetRestSeconds: p.restSeconds
                    )
                }

            return WorkoutSessionFactory.ExerciseTemplate(
                order: item.order,
                exerciseId: ex.id,
                nameSnapshot: ex.name,
                notes: item.notes,
                sets: sets
            )
        }
    }
}
