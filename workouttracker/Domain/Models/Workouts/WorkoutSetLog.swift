import Foundation
import SwiftData

@Model
final class WorkoutSetLog {
    @Attribute(.unique) var id: UUID

    var order: Int
    var originRaw: String

    // Actuals
    var reps: Int?
    var weight: Double?
    var weightUnitRaw: String
    var rpe: Double?
    var completed: Bool
    var completedAt: Date?

    // Plan snapshot
    var targetReps: Int?
    var targetWeight: Double?
    var targetWeightUnitRaw: String
    var targetRPE: Double?
    var targetRestSeconds: Int?

    var sessionExercise: WorkoutSessionExercise?

    init(
        id: UUID = UUID(),
        order: Int,
        origin: WorkoutSetOrigin = .planned,
        reps: Int? = nil,
        weight: Double? = nil,
        weightUnit: WeightUnit = .kg,
        rpe: Double? = nil,
        completed: Bool = false,
        completedAt: Date? = nil,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetWeightUnit: WeightUnit = .kg,
        targetRPE: Double? = nil,
        targetRestSeconds: Int? = nil,
        sessionExercise: WorkoutSessionExercise? = nil
    ) {
        self.id = id
        self.order = order
        self.originRaw = origin.rawValue

        self.reps = reps
        self.weight = weight
        self.weightUnitRaw = weightUnit.rawValue
        self.rpe = rpe
        self.completed = completed
        self.completedAt = completedAt

        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetWeightUnitRaw = targetWeightUnit.rawValue
        self.targetRPE = targetRPE
        self.targetRestSeconds = targetRestSeconds

        self.sessionExercise = sessionExercise
    }

    var origin: WorkoutSetOrigin {
        get { WorkoutSetOrigin(rawValue: originRaw) ?? .planned }
        set { originRaw = newValue.rawValue }
    }

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
        set { weightUnitRaw = newValue.rawValue }
    }

    var targetWeightUnit: WeightUnit {
        get { WeightUnit(rawValue: targetWeightUnitRaw) ?? .kg }
        set { targetWeightUnitRaw = newValue.rawValue }
    }
}
