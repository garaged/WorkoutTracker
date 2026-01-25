import Foundation

struct WorkoutContinueNavigator {

    func nextTargetSetID(
        exercises: [WorkoutSessionExercise],
        activeExerciseID: UUID?,
        activeSetID: UUID?
    ) -> UUID? {
        let orderedExercises = exercises.sorted { $0.order < $1.order }
        guard !orderedExercises.isEmpty else { return nil }

        let activeIndex = activeExerciseID.flatMap { id in
            orderedExercises.firstIndex(where: { $0.id == id })
        } ?? 0

        func nextIncomplete(in ex: WorkoutSessionExercise, after setID: UUID?) -> UUID? {
            let sets = ex.setLogs.sorted { $0.order < $1.order }
            guard !sets.isEmpty else { return nil }

            let startIndex = setID.flatMap { sid in sets.firstIndex(where: { $0.id == sid }) }
            if let startIndex, startIndex + 1 < sets.count {
                if let found = sets[(startIndex + 1)...].first(where: { !$0.completed }) {
                    return found.id
                }
            }
            return sets.first(where: { !$0.completed })?.id
        }

        if let id = nextIncomplete(in: orderedExercises[activeIndex], after: activeSetID) { return id }

        if activeIndex + 1 < orderedExercises.count {
            for i in (activeIndex + 1)..<orderedExercises.count {
                if let id = nextIncomplete(in: orderedExercises[i], after: nil) { return id }
            }
        }

        for ex in orderedExercises {
            if let id = nextIncomplete(in: ex, after: nil) { return id }
        }

        if let lastEx = orderedExercises.last {
            return lastEx.setLogs.sorted(by: { $0.order < $1.order }).last?.id
        }
        return nil
    }
}
