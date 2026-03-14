import Foundation

// File: workouttracker/Domain/Models/Workouts/SessionSegmentKind.swift
//
// Why this file lives here:
// Segment identity is part of the workout domain model and needs to be shared by
// routine planning, session persistence, history, and later analytics.

enum SessionSegmentKind: String, Codable, CaseIterable {
    case warmUp
    case main
    case coolDown
}
