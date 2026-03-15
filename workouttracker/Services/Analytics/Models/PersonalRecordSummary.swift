import Foundation

enum PersonalRecordKind: String, Codable, CaseIterable, Hashable {
    case heaviestWeight
    case mostReps
    case highestEstimatedOneRepMax
    case highestSessionVolume
}

struct PersonalRecordSummary: Hashable {
    let kind: PersonalRecordKind
    let previousBest: Double?
    let currentBest: Double
    let achievedAt: Date
    let sessionID: UUID
    let isNewRecord: Bool
    let contextWeight: Double?
}
