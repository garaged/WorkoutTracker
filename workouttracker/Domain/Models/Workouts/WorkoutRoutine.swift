import Foundation
import SwiftData

@Model
final class WorkoutRoutine {
    @Attribute(.unique) var id: UUID

    var name: String
    var notes: String?
    var isArchived: Bool

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var items: [WorkoutRoutineItem] = []

    // Annotate only this side.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutRoutine.usedAsWarmUpBy)
    var warmUpRoutine: WorkoutRoutine?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutRoutine.usedAsCoolDownBy)
    var coolDownRoutine: WorkoutRoutine?

    // Let SwiftData infer these as the inverse side.
    var usedAsWarmUpBy: [WorkoutRoutine] = []
    var usedAsCoolDownBy: [WorkoutRoutine] = []

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
        self.warmUpRoutine = nil
        self.coolDownRoutine = nil
    }
}
