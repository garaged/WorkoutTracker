import Foundation
import Observation

@Observable
final class GoalPrefillStore {

    struct Target: Hashable {
        let exerciseId: UUID
        let weight: Double?
        let reps: Int?
        let createdAt: Date

        init(exerciseId: UUID, weight: Double? = nil, reps: Int? = nil, createdAt: Date = Date()) {
            self.exerciseId = exerciseId
            self.weight = weight
            self.reps = reps
            self.createdAt = createdAt
        }
    }

    private(set) var pending: Target?

    var pendingExerciseId: UUID? { pending?.exerciseId }

    func set(_ target: Target) {
        pending = target
    }

    /// One-shot consume: prevents the goal from “sticking” forever and accidentally applying later.
    func consumeIfMatches(exerciseId: UUID) -> Target? {
        guard let p = pending, p.exerciseId == exerciseId else { return nil }
        pending = nil
        return p
    }
}
