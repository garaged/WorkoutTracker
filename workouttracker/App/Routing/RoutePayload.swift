import Foundation

enum RoutePayload: Hashable, Equatable {
    case home
    case session(SessionPayload)
    case trackedActivity(TrackedActivityPayload)
    case routine(RoutinePayload)
    case calendarDay(CalendarDayPayload)

    struct SessionPayload: Hashable, Equatable {
        let sessionID: UUID
        let target: Target

        enum Target: Hashable, Equatable {
            case session
            case exercise(UUID)
            case rest
        }
    }

    struct TrackedActivityPayload: Hashable, Equatable {
        let sessionID: UUID
    }

    struct RoutinePayload: Hashable, Equatable {
        let routineID: UUID
    }

    struct CalendarDayPayload: Hashable, Equatable {
        let date: Date
    }
}
