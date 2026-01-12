import Foundation
import SwiftData

@Model
final class WorkoutSetPlan {
    @Attribute(.unique) var id: UUID

    var order: Int

    var targetReps: Int?
    var targetWeight: Double?
    var weightUnitRaw: String

    var targetRPE: Double?
    var restSeconds: Int?

    /// Belongs-to
    var routineItem: WorkoutRoutineItem?

    init(
        id: UUID = UUID(),
        order: Int,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        weightUnit: WeightUnit = .kg,
        targetRPE: Double? = nil,
        restSeconds: Int? = nil,
        routineItem: WorkoutRoutineItem? = nil
    ) {
        self.id = id
        self.order = order
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.weightUnitRaw = weightUnit.rawValue
        self.targetRPE = targetRPE
        self.restSeconds = restSeconds
        self.routineItem = routineItem
    }

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
        set { weightUnitRaw = newValue.rawValue }
    }
}
