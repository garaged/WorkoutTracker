import Foundation

enum SessionMutationAction {
    case toggleSetCompleted
    case addSet
    case copySet
    case deleteSet
    case bumpReps
    case bumpWeight
    case editSetFields
    case useRestTimer
    case finishExercise
}

struct SessionLifecyclePolicy {
    func canMutateProgress(_ session: WorkoutSession) -> Bool {
        session.status == .inProgress && !session.isPaused && session.endedAt == nil
    }

    func allows(_ action: SessionMutationAction, on session: WorkoutSession) -> Bool {
        switch action {
        case .toggleSetCompleted,
             .addSet,
             .copySet,
             .deleteSet,
             .bumpReps,
             .bumpWeight,
             .editSetFields,
             .useRestTimer,
             .finishExercise:
            return canMutateProgress(session)
        }
    }
}
