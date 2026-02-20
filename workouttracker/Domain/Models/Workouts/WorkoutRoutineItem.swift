import Foundation
import SwiftData

@Model
final class WorkoutRoutineItem {
    @Attribute(.unique) var id: UUID

    var order: Int
    var notes: String?

    var routine: WorkoutRoutine?
    var exercise: Exercise?

    // ✅ Persisted value (SwiftData-friendly). MUST be a literal default.
    var trackingStyleRaw: String = "strength"

    @Relationship(deleteRule: .cascade)
    var setPlans: [WorkoutSetPlan] = []

    init(
        id: UUID = UUID(),
        order: Int,
        routine: WorkoutRoutine? = nil,
        exercise: Exercise? = nil,
        notes: String? = nil,
        trackingStyleRaw: String = "strength"
    ) {
        self.id = id
        self.order = order
        self.routine = routine
        self.exercise = exercise
        self.notes = notes
        self.trackingStyleRaw = trackingStyleRaw
    }
}
