import Foundation

struct TrackedActivityRecoveryPlanner {
    enum RecoveryState: Equatable {
        case none
        case live
        case paused
        case interrupted
        case staleNeedsPrompt
        case staleSuppressed

        var priority: Int {
            switch self {
            case .staleNeedsPrompt: return 0
            case .paused: return 1
            case .interrupted: return 2
            case .staleSuppressed: return 3
            case .live: return 4
            case .none: return 5
            }
        }

        var isStale: Bool {
            switch self {
            case .staleNeedsPrompt, .staleSuppressed:
                return true
            case .none, .live, .paused, .interrupted:
                return false
            }
        }

        var shouldShowPrompt: Bool {
            self == .staleNeedsPrompt
        }
    }

    enum HealthFollowUpState: Equatable {
        case none
        case exportPending
        case exportFailed
        case savedWithLocalChanges

        var priority: Int {
            switch self {
            case .exportFailed: return 0
            case .exportPending: return 1
            case .savedWithLocalChanges: return 2
            case .none: return 3
            }
        }
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func recoveryState(for session: TrackedActivitySession, now: Date = Date()) -> RecoveryState {
        guard session.lifecycleState == .inProgress || session.lifecycleState == .paused else {
            return .none
        }

        let recoveryAnchor = session.lastResumedAt ?? session.startedAt ?? session.createdAt
        let isPreviousDay = calendar.startOfDay(for: recoveryAnchor) < calendar.startOfDay(for: now)

        if isPreviousDay {
            if let dismissedAt = session.dismissedRecoveryPromptAt,
               calendar.isDate(dismissedAt, inSameDayAs: now) {
                return .staleSuppressed
            }
            return .staleNeedsPrompt
        }

        if session.lifecycleState == .paused {
            return .paused
        }

        if let backgroundedAt = session.lastBackgroundedAt {
            let reopenAnchor = session.lastResumedAt ?? session.startedAt ?? session.createdAt
            if backgroundedAt >= reopenAnchor {
                return .interrupted
            }
        }

        return .live
    }

    func healthFollowUpState(for session: TrackedActivitySession) -> HealthFollowUpState {
        guard session.lifecycleState == .completed else { return .none }

        switch session.healthKitExportState {
        case .pending:
            return .exportPending
        case .failed:
            return .exportFailed
        case .exported where session.hasLocalChangesSinceHealthKitExport:
            return .savedWithLocalChanges
        case .notRequested, .notAvailable, .exported:
            return .none
        }
    }

    func sortedRecoverySessions(_ sessions: [TrackedActivitySession], now: Date = Date()) -> [TrackedActivitySession] {
        sessions.sorted { lhs, rhs in
            let lhsState = recoveryState(for: lhs, now: now)
            let rhsState = recoveryState(for: rhs, now: now)
            if lhsState.priority != rhsState.priority {
                return lhsState.priority < rhsState.priority
            }

            let lhsAnchor = lhs.lastResumedAt ?? lhs.startedAt ?? lhs.createdAt
            let rhsAnchor = rhs.lastResumedAt ?? rhs.startedAt ?? rhs.createdAt
            if lhsAnchor != rhsAnchor {
                return lhsAnchor > rhsAnchor
            }

            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func sortedHealthFollowUpSessions(_ sessions: [TrackedActivitySession]) -> [TrackedActivitySession] {
        sessions
            .filter { healthFollowUpState(for: $0) != .none }
            .sorted { lhs, rhs in
                let lhsState = healthFollowUpState(for: lhs)
                let rhsState = healthFollowUpState(for: rhs)
                if lhsState.priority != rhsState.priority {
                    return lhsState.priority < rhsState.priority
                }
                let lhsDate = lhs.healthKitExportAttemptedAt ?? lhs.healthKitExportSucceededAt ?? lhs.endedAt ?? lhs.updatedAt
                let rhsDate = rhs.healthKitExportAttemptedAt ?? rhs.healthKitExportSucceededAt ?? rhs.endedAt ?? rhs.updatedAt
                return lhsDate > rhsDate
            }
    }
}
