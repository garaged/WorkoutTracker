// workouttracker/Services/Programs/ProgramPackV2.swift
import Foundation
import Combine

struct ProgramPackV2: Codable {
    var formatVersion: Int
    var generatedAt: Date?
    var exercises: [ExerciseDTO]
    var routines: [RoutineDTO]
    var programs: [TrainingProgram]
}

struct ExerciseDTO: Codable, Hashable {
    /// Slug remains part of the pack contract for compatibility.
    /// - Built-in exercises should export a slug derived from `catalogKey`.
    /// - Custom exercises should export a slug derived from `name`.
    var slug: String

    /// Human-readable display name used for previews and fallback import behavior.
    var name: String

    /// Stable built-in exercise identity when this DTO represents a bundled/catalog exercise.
    /// Custom exercises leave this nil and continue to rely on `slug + name`.
    var catalogKey: String?

    var modality: String   // ExerciseModality.rawValue
    var instructions: String?
    var notes: String?
    var equipmentTags: [String]?
}

struct RoutineDTO: Codable, Hashable {
    var slug: String
    var name: String
    var notes: String?
    var items: [RoutineItemDTO]
}

struct RoutineItemDTO: Codable, Hashable {
    var order: Int
    var exerciseSlug: String
    var trackingStyle: String // ExerciseTrackingStyle.rawValue
    var notes: String?
    var setPlans: [SetPlanDTO]
}

struct SetPlanDTO: Codable, Hashable {
    var order: Int
    var targetReps: Int?
    var targetWeight: Double?
    var weightUnit: String? // WeightUnit.rawValue
    var targetDurationSeconds: Int?
    var targetDistance: Double?
    var targetRpe: Double?
    var restSeconds: Int?
}
