import Foundation
import SwiftData

@Model
final class WorkoutRoutineItem {
    @Attribute(.unique) var id: UUID

    /// Ordering inside a routine
    var order: Int
    var notes: String?

    /// Belongs-to
    var routine: WorkoutRoutine?

    /// Which exercise this item refers to
    var exercise: Exercise?
    
    var trackingStyle: ExerciseTrackingStyle = .strength
    
    // ✅ Item -> planned sets (cascade), no inverse
    @Relationship(deleteRule: .cascade)
    var setPlans: [WorkoutSetPlan] = []

    init(
        id: UUID = UUID(),
        order: Int,
        routine: WorkoutRoutine? = nil,
        exercise: Exercise? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.order = order
        self.routine = routine
        self.exercise = exercise
        self.notes = notes
    }
}
