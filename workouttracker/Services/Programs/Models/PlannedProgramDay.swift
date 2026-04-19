import Foundation

struct PlannedProgramDay: Identifiable, Equatable {
    enum State: Equatable {
        case rest
        case upcoming
        case scheduledToday
        case completed
        case missed
    }

    let id: String
    let weekIndex: Int
    let dayIndex: Int
    let title: String
    let scheduledDate: Date
    let kind: ProgramDayKind
    let isRequired: Bool
    let state: State
    let routineSlug: String?
    let isCurrentWeek: Bool
    let isNextActionable: Bool
}
