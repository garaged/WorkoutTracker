// File: Domain/Models/Workouts/WorkoutSetOrigin.swift
import Foundation

enum WorkoutSetOrigin: String, Codable, CaseIterable {
    case planned   // came from WorkoutSetPlan
    case added     // user added a set during the session (via row actions)
}
