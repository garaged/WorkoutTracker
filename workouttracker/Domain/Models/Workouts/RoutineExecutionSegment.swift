import Foundation

// File: workouttracker/Domain/Models/Workouts/RoutineExecutionSegment.swift
//
// Why this file lives here:
// This is a domain planning object that bridges persisted linked routines and the
// eventual session execution flow. It stays intentionally UI-free so session
// screens can decide later how to present segment boundaries.

struct RoutineExecutionSegment: Identifiable {
    let id: UUID
    let kind: SessionSegmentKind
    let routineID: UUID?
    let routineName: String
    let exerciseItems: [WorkoutRoutineItem]

    init(
        id: UUID = UUID(),
        kind: SessionSegmentKind,
        routineID: UUID?,
        routineName: String,
        exerciseItems: [WorkoutRoutineItem]
    ) {
        self.id = id
        self.kind = kind
        self.routineID = routineID
        self.routineName = routineName
        self.exerciseItems = exerciseItems
    }
}
