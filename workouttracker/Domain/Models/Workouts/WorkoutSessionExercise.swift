import Foundation
import SwiftData

@Model
final class WorkoutSessionExercise {
    @Attribute(.unique) var id: UUID

    var order: Int
    var exerciseId: UUID
    var exerciseNameSnapshot: String
    var notes: String?

    /// Belongs-to
    var session: WorkoutSession?

    // ✅ Parent -> children (cascade), no inverse
    @Relationship(deleteRule: .cascade)
    var setLogs: [WorkoutSetLog] = []

    init(
        id: UUID = UUID(),
        order: Int,
        exerciseId: UUID,
        exerciseNameSnapshot: String,
        notes: String? = nil,
        session: WorkoutSession? = nil
    ) {
        self.id = id
        self.order = order
        self.exerciseId = exerciseId
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.notes = notes
        self.session = session
    }
}
