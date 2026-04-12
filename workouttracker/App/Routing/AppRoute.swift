import Foundation

enum AppRoute: Hashable, Equatable {
    case home
    case session(sessionID: UUID)
    case sessionExercise(sessionID: UUID, exerciseID: UUID)
    case sessionRest(sessionID: UUID)
    case trackedActivity(sessionID: UUID)
    case routine(routineID: UUID)
    case calendarDay(date: Date)

    var sessionID: UUID? {
        switch self {
        case .session(let sessionID),
             .sessionExercise(let sessionID, _),
             .sessionRest(let sessionID),
             .trackedActivity(let sessionID):
            return sessionID
        default:
            return nil
        }
    }

    var exerciseID: UUID? {
        switch self {
        case .sessionExercise(_, let exerciseID):
            return exerciseID
        default:
            return nil
        }
    }

    var routineID: UUID? {
        switch self {
        case .routine(let routineID):
            return routineID
        default:
            return nil
        }
    }

    var calendarDay: Date? {
        switch self {
        case .calendarDay(let date):
            return date
        default:
            return nil
        }
    }
}
