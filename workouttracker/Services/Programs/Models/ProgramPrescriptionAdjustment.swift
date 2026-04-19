import Foundation

struct ProgramPrescriptionAdjustment: Equatable {
    enum Action: Equatable {
        case increaseLoad
        case increaseReps
        case hold
        case deload
        case advance
    }

    enum Reason: Equatable {
        case metTarget
        case repRangeProgression
        case scheduledDeload
        case failedTarget
        case insufficientData
        case noRuleConfigured
        case failureThresholdReached
        case invalidRuleConfiguration
        case unitMismatch
    }

    let prescriptionID: UUID
    let exerciseID: UUID?
    let exerciseNameSnapshot: String?
    let action: Action
    let reason: Reason
    let nextTargetReps: Int?
    let nextTargetWeight: Double?
    let nextTargetWeightUnit: WeightUnit?
    let nextTargetDurationSeconds: Int?
    let nextTargetDistance: Double?
    let nextTargetDistanceUnit: DistanceUnit?
    let nextTargetRPE: Double?
    let suggestsRepeatWeek: Bool
}
