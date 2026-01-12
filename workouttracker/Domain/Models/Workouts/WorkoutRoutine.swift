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

    // ✅ Parent -> children, no inverse to avoid macro cycles
    @Relationship(deleteRule: .cascade)
    var items: [WorkoutRoutineItem] = []

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
    }
}
