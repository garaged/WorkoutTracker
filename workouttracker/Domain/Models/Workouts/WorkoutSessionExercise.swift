import Foundation
import SwiftData

@Model
final class WorkoutSessionExercise {
    @Attribute(.unique) var id: UUID

    var order: Int

    // Snapshot identity (session stays stable even if Exercise changes later)
    var exerciseId: UUID
    var exerciseNameSnapshot: String

    var notes: String?

    // Explicit relationship (no inverse to avoid macro circular-reference issues)
    @Relationship(deleteRule: .nullify)
    var session: WorkoutSession?

    // Persisted relationship (different name => avoids macro accessor collision on `setLogs`)
    @Relationship(deleteRule: .cascade)
    var setLogsStorage: [WorkoutSetLog]
    
    var targetDurationSeconds: Int? = nil
    var actualDurationSeconds: Int? = nil
    var targetDistance: Double? = nil
    var actualDistance: Double? = nil

    // Public API the rest of the app keeps using (not persisted)
    @Transient
    var setLogs: [WorkoutSetLog] {
        get { setLogsStorage }
        set {
            setLogsStorage = newValue
            // Keep backrefs consistent even without inverses
            for log in setLogsStorage {
                log.sessionExercise = self
            }
        }
    }

    init(
        id: UUID = UUID(),
        order: Int,
        exerciseId: UUID,
        exerciseNameSnapshot: String,
        notes: String? = nil,
        session: WorkoutSession? = nil,
        setLogsStorage: [WorkoutSetLog] = []
    ) {
        self.id = id
        self.order = order
        self.exerciseId = exerciseId
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.notes = notes
        self.session = session

        self.setLogsStorage = setLogsStorage

        // Keep backrefs consistent even without inverses
        for log in self.setLogsStorage {
            log.sessionExercise = self
        }
    }
    
    @Transient
    var orderedSetLogs: [WorkoutSetLog] {
        setLogsStorage.sorted { $0.order < $1.order }
    }
}
