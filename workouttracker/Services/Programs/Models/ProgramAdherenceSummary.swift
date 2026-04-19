import Foundation

struct ProgramAdherenceSummary: Equatable {
    let position: ProgramPosition
    let currentWeekCompletion: ProgramWeekCompletion
    let completedRequiredDays: Int
    let missedRequiredDays: Int
    let outstandingMissedDays: Int
    let recommendation: ProgramRecommendation
}
