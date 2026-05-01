import Foundation

struct WatchRecoveryEvaluator {
    struct SourceState: Equatable {
        var isActiveSession: Bool
        var isTrackedActivitySession: Bool
        var isPaused: Bool
        var isRestRunning: Bool
        var restEndsAtEpochSeconds: TimeInterval?
        var elapsedSeconds: Int?
        var elapsedUpdatedAtEpochSeconds: TimeInterval?

        init(
            isActiveSession: Bool = false,
            isTrackedActivitySession: Bool = false,
            isPaused: Bool = false,
            isRestRunning: Bool = false,
            restEndsAtEpochSeconds: TimeInterval? = nil,
            elapsedSeconds: Int? = nil,
            elapsedUpdatedAtEpochSeconds: TimeInterval? = nil
        ) {
            self.isActiveSession = isActiveSession
            self.isTrackedActivitySession = isTrackedActivitySession
            self.isPaused = isPaused
            self.isRestRunning = isRestRunning
            self.restEndsAtEpochSeconds = restEndsAtEpochSeconds
            self.elapsedSeconds = elapsedSeconds
            self.elapsedUpdatedAtEpochSeconds = elapsedUpdatedAtEpochSeconds
        }
    }

    enum TransportStatus: Equatable {
        case reconnecting
        case phoneUnavailable
        case phoneClosed
    }

    enum TrackedActivityStatus: Equatable {
        case paused
        case pausedReconnecting
        case liveReconnecting
        case trackingLiveOnPhone
    }

    let recoveryGraceInterval: TimeInterval

    init(recoveryGraceInterval: TimeInterval = 20) {
        self.recoveryGraceInterval = recoveryGraceInterval
    }

    func isTransportHealthy(canSendCommands: Bool, isReachable: Bool) -> Bool {
        canSendCommands && isReachable
    }

    func isRecoveringRecentSession(
        sourceIsActiveSession: Bool,
        canSendCommands: Bool,
        isReachable: Bool,
        lastKnownActiveSession: Bool,
        lastStateReceivedAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard !sourceIsActiveSession else { return false }
        guard !isTransportHealthy(canSendCommands: canSendCommands, isReachable: isReachable) else { return false }
        guard lastKnownActiveSession else { return false }
        guard let lastStateReceivedAt else { return false }
        return now.timeIntervalSince(lastStateReceivedAt) <= recoveryGraceInterval
    }

    func hasRecoverableNowPlayingSession(displayedIsActiveSession: Bool, isRecoveringRecentSession: Bool) -> Bool {
        displayedIsActiveSession || isRecoveringRecentSession
    }

    func transportStatus(
        isRecoveringRecentSession: Bool,
        canSendCommands: Bool,
        isReachable: Bool
    ) -> TransportStatus? {
        if isRecoveringRecentSession {
            return .reconnecting
        }
        if !canSendCommands {
            return .phoneUnavailable
        }
        if !isReachable {
            return .phoneClosed
        }
        return nil
    }

    func trackedActivityStatus(isPaused: Bool, isRecoveringRecentSession: Bool) -> TrackedActivityStatus {
        if isPaused {
            return isRecoveringRecentSession ? .pausedReconnecting : .paused
        }
        return isRecoveringRecentSession ? .liveReconnecting : .trackingLiveOnPhone
    }

    func shouldRunLocalTicker(
        for source: SourceState,
        isRecoveringRecentSession: Bool,
        now: Date = Date()
    ) -> Bool {
        if source.isRestRunning, let end = source.restEndsAtEpochSeconds {
            let maxRecoverableOverdueInterval: TimeInterval = 20 * 60
            return end.isFinite && end >= now.timeIntervalSince1970 - maxRecoverableOverdueInterval
        }

        if source.isTrackedActivitySession,
           source.isActiveSession,
           !source.isPaused,
           source.elapsedSeconds != nil,
           source.elapsedUpdatedAtEpochSeconds != nil {
            return true
        }

        if isRecoveringRecentSession {
            return true
        }

        return false
    }
}
