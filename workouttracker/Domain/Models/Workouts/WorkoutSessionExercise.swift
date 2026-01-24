import Foundation
import SwiftData

@Model
final class WorkoutSessionExercise {
    @Attribute(.unique) var id: UUID

    var order: Int
    var exerciseId: UUID
    var exerciseNameSnapshot: String
    var notes: String?

    var session: WorkoutSession?

    // Persisted relationship (different name => avoids macro accessor collision on `setLogs`)
    @Relationship(deleteRule: .cascade)
    var setLogsStorage: [WorkoutSetLog]

    // Public API the rest of the app keeps using
    var setLogs: [WorkoutSetLog] {
        get { setLogsStorage }
        set { setLogsStorage = newValue }
    }

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

        self.setLogsStorage = []
    }
}
