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

    /// Structural origin for analytics and future segmented routines.
    /// Keep a raw persisted value for SwiftData compatibility.
    var segmentRaw: String = "main"

    @Relationship(deleteRule: .cascade)
    var setPlans: [WorkoutSetPlan] = []

    init(
        id: UUID = UUID(),
        order: Int,
        routine: WorkoutRoutine? = nil,
        exercise: Exercise? = nil,
        notes: String? = nil,
        trackingStyleRaw: String = "strength",
        segmentRaw: String = "main"
    ) {
        self.id = id
        self.order = order
        self.routine = routine
        self.exercise = exercise
        self.notes = notes
        self.trackingStyleRaw = trackingStyleRaw
        self.segmentRaw = segmentRaw
    }

    var segment: WorkoutExerciseSegment {
        get { WorkoutExerciseSegment(rawValue: segmentRaw) ?? .main }
        set { segmentRaw = newValue.rawValue }
    }
}
