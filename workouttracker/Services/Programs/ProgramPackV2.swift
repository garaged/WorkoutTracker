// workouttracker/Services/Programs/ProgramPackV2.swift
import Foundation

struct ProgramPackV2: Codable {
    var formatVersion: Int
    var generatedAt: Date?
    var exercises: [ExerciseDTO]
    var routines: [RoutineDTO]
    var programs: [TrainingProgram]
}

struct ExerciseDTO: Codable, Hashable {
    var slug: String
    var name: String
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
