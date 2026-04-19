import Foundation

struct ProgramPosition: Equatable {
    let assignmentID: UUID
    let programID: UUID
    let asOfDate: Date
    let scheduledWeekIndex: Int
    let currentWeekIndex: Int
    let currentDayIndex: Int?
    let nextActionableWeekIndex: Int?
    let nextActionableDayIndex: Int?
    let isBehindSchedule: Bool
    let isProgramComplete: Bool
}
