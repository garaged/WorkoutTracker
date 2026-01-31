import Foundation
import Combine

/// Stores one-shot “goal prefills” that can be applied when starting/logging a workout.
@MainActor
final class GoalPrefillStore: ObservableObject {

    struct Prefill: Hashable, Codable {
        var exerciseId: UUID
        var weight: Double?
        var reps: Int?

        init(exerciseId: UUID, weight: Double? = nil, reps: Int? = nil) {
            self.exerciseId = exerciseId
            self.weight = weight
            self.reps = reps
        }
    }

    /// Prefills are stored per-exercise so multiple can be queued.
    @Published private var storage: [UUID: Prefill] = [:]

    /// The “active” exercise id that should receive the next prefill application.
    /// This matches how your WorkoutSessionScreen applies targets.
    @Published private(set) var pendingExerciseId: UUID? = nil

    init() {}

    // MARK: - Write

    func set(_ prefill: Prefill) {
        storage[prefill.exerciseId] = prefill
        pendingExerciseId = prefill.exerciseId
    }

    func clear(exerciseId: UUID) {
        storage.removeValue(forKey: exerciseId)
        if pendingExerciseId == exerciseId {
            pendingExerciseId = storage.keys.first
        }
    }

    func clearAll() {
        storage.removeAll()
        pendingExerciseId = nil
    }

    // MARK: - Read

    func peek(exerciseId: UUID) -> Prefill? {
        storage[exerciseId]
    }

    /// Read-once: returns the prefill and removes it.
    func consume(exerciseId: UUID) -> Prefill? {
        guard let p = storage[exerciseId] else { return nil }
        storage.removeValue(forKey: exerciseId)

        if pendingExerciseId == exerciseId {
            pendingExerciseId = storage.keys.first
        }
        return p
    }

    /// Your session screen logic: only consume if it matches the pending exercise.
    func consumeIfMatches(exerciseId: UUID) -> Prefill? {
        guard pendingExerciseId == exerciseId else { return nil }
        return consume(exerciseId: exerciseId)
    }
}
