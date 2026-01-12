// Services/Workouts/WorkoutSessionFactory.swift
import Foundation
import SwiftData

@MainActor
struct WorkoutSessionFactory {

    enum FactoryError: Error {
        case routineHasNoItems
        case routineItemMissingExercise(itemId: UUID)
    }

    /// Creates + inserts a WorkoutSession from an Activity + WorkoutRoutine by snapshotting:
    /// - routine items -> session exercises
    /// - setPlans -> set logs (targets)
    ///
    /// This is intentionally UI-free.
    func createSession(
        activity: Activity,
        routine: WorkoutRoutine,
        context: ModelContext
    ) throws -> WorkoutSession {

        // 1) Ensure we have items to snapshot
        let items = routine.itemsSortedByOrder
        guard !items.isEmpty else { throw FactoryError.routineHasNoItems }

        // 2) Create the session root
        let session = WorkoutSession(
            startedAt: activity.startAt,
            sourceRoutineId: routine.id,
            sourceRoutineNameSnapshot: routine.name,
            linkedActivityId: activity.id
        )

        // 3) Snapshot each routine item -> session exercise + set logs
        for item in items {
            guard let exercise = item.exercise else {
                // Opinionated: if the routine is inconsistent, fail loudly.
                throw FactoryError.routineItemMissingExercise(itemId: item.id)
            }

            // NOTE: Adapt this initializer to your actual WorkoutSessionExercise init signature.
            // The code assumes you have at least: (order: Int, exercise: Exercise?)
            let sessionExercise = WorkoutSessionExercise(
                id: item.id,
                order: item.order,
                exerciseId: item.id,
                exerciseNameSnapshot: exercise.name,
                notes: item.notes,
                session: session
            )

//            init(
//                id: UUID = UUID(),
//                order: Int,
//                exerciseId: UUID,
//                exerciseNameSnapshot: String,
//                notes: String? = nil,
//                session: WorkoutSession? = nil
//            )
            
            // Attach to session (parent -> children)
            session.exercises.append(sessionExercise)

            // Plans are snapshot into set logs
            let plans = item.setPlansSortedByOrder

            if plans.isEmpty {
                // Ensure at least one planned set exists.
                let log = WorkoutSetLog(
                    order: 0,
                    origin: .planned,
                    targetReps: nil,
                    targetWeight: nil,
                    targetWeightUnit: .kg,
                    targetRPE: nil,
                    targetRestSeconds: nil,
                    sessionExercise: sessionExercise
                )
                sessionExercise.setLogs.append(log) // assumes WorkoutSessionExercise has setLogs
            } else {
                for plan in plans {
                    let log = WorkoutSetLog(
                        order: plan.order,
                        origin: .planned,
                        targetReps: plan.targetReps,
                        targetWeight: plan.targetWeight,
                        //targetWeightUnit: plan., // adapt if your plan stores raw
                        targetRPE: plan.targetRPE,
                        //targetRestSeconds: plan.,
                        sessionExercise: sessionExercise
                    )
                    sessionExercise.setLogs.append(log) // assumes WorkoutSessionExercise has setLogs
                }
            }
        }

        // 4) Persist
        context.insert(session)
        try context.save()
        return session
    }
}

// MARK: - Ordering helpers

private extension WorkoutRoutine {
    var itemsSortedByOrder: [WorkoutRoutineItem] {
        items.sorted { $0.order < $1.order }
    }
}

private extension WorkoutRoutineItem {
    var setPlansSortedByOrder: [WorkoutSetPlan] {
        setPlans.sorted { $0.order < $1.order }
    }
}
