import Foundation
import SwiftData

// File: workouttracker/Domain/Models/Workouts/WorkoutRoutine.swift
//
// Patch:
// - Restores missing imports so SwiftData macros compile.
// - Keeps a simple model shape (id/name/notes/items) that matches your existing UI.

@Model
final class WorkoutRoutine {
    @Attribute(.unique) var id: UUID

    var name: String
    var notes: String?
    var isArchived: Bool

    var createdAt: Date
    var updatedAt: Date

    // Parent -> children. Cascade delete so removing a routine removes its items.
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
