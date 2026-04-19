import Foundation

struct ProgressionDecision: Equatable {
    enum Action: Equatable {
        case increase
        case hold
        case repeatWeek
        case deload
        case advance
    }

    enum Reason: Equatable {
        case prescriptionsProgressed
        case insufficientData
        case targetNotMet
        case failureThresholdReached
        case scheduledDeload
        case noRuleConfigured
        case invalidRuleConfiguration
    }

    let sessionID: UUID
    let assignmentID: UUID?
    let programID: UUID?
    let weekIndex: Int?
    let dayIndex: Int?
    let action: Action
    let reason: Reason
    let adjustments: [ProgramPrescriptionAdjustment]
}
