import Foundation

struct ProgramWeekCompletion: Equatable {
    let weekIndex: Int
    let requiredDays: Int
    let completedRequiredDays: Int
    let missedRequiredDays: Int
    let remainingRequiredDays: Int

    var isComplete: Bool {
        requiredDays > 0 && completedRequiredDays >= requiredDays && remainingRequiredDays == 0
    }
}
