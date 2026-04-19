import Foundation

struct ProgramRecommendation: Equatable {
    enum Kind: Equatable {
        case startWeek
        case advanceToNextDay
        case completeMissedDay
        case repeatWeek
        case completeProgram
    }

    enum Reason: Equatable {
        case weekNotStarted
        case nextIncompleteDay
        case outstandingMissedDay
        case missedRequiredDays
        case programFinished
    }

    let kind: Kind
    let reason: Reason
    let weekIndex: Int?
    let dayIndex: Int?
}
