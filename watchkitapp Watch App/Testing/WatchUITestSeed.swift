import Foundation

struct WatchUITestSeed {
    enum Route: String {
        case shortcuts
        case nowPlaying
    }

    enum State: String {
        case inactive
        case trackedPaused
        case trackedActive
    }

    let route: Route
    let state: State
    let canSendCommands: Bool
    let isReachable: Bool
    let lastStateReceivedAt: Date?

    static var current: WatchUITestSeed? {
        let env = ProcessInfo.processInfo.environment
        guard env["UITESTS"] == "1" || env["WATCH_UITESTS"] == "1" else { return nil }
        let route = Route(rawValue: env["WATCH_UITEST_ROUTE"] ?? "shortcuts") ?? .shortcuts
        let state = State(rawValue: env["WATCH_UITEST_STATE"] ?? "trackedPaused") ?? .trackedPaused
        let canSendCommands = env["WATCH_UITEST_CAN_SEND_COMMANDS"].map { $0 != "0" } ?? true
        let isReachable = env["WATCH_UITEST_IS_REACHABLE"].map { $0 == "1" } ?? true
        let secondsAgo = Double(env["WATCH_UITEST_LAST_STATE_SECONDS_AGO"] ?? "0") ?? 0
        let lastStateReceivedAt = Date().addingTimeInterval(-max(0, secondsAgo))
        return WatchUITestSeed(route: route, state: state, canSendCommands: canSendCommands, isReachable: isReachable, lastStateReceivedAt: lastStateReceivedAt)
    }

    var nowPlayingState: WatchNowPlayingState {
        switch state {
        case .inactive:
            return .inactive
        case .trackedPaused:
            return WatchNowPlayingState(
                presentationKind: .trackedActivity,
                isActiveSession: true,
                exerciseName: String(localized: "watch.uitest.activity.title", defaultValue: "Outdoor walk"),
                setTitle: String(localized: "watch.uitest.activity.subtitle.paused", defaultValue: "Paused tracked activity"),
                setDetail: String(localized: "watch.uitest.activity.detail", defaultValue: "Open controls smoke seed"),
                isRestRunning: false,
                restRemainingSeconds: nil,
                restEndsAtEpochSeconds: nil,
                canGoPrevious: false,
                canGoNext: false,
                isPaused: true,
                canPauseOrResume: true,
                canFinish: true,
                elapsedSeconds: 185,
                elapsedUpdatedAtEpochSeconds: Date().timeIntervalSince1970,
                sessionID: "watch-uitest-session",
                setID: nil,
                quickStartRoutines: []
            )
        case .trackedActive:
            return WatchNowPlayingState(
                presentationKind: .trackedActivity,
                isActiveSession: true,
                exerciseName: String(localized: "watch.uitest.activity.title", defaultValue: "Outdoor walk"),
                setTitle: String(localized: "watch.uitest.activity.subtitle.active", defaultValue: "Live tracked activity"),
                setDetail: String(localized: "watch.uitest.activity.detail", defaultValue: "Open controls smoke seed"),
                isRestRunning: false,
                restRemainingSeconds: nil,
                restEndsAtEpochSeconds: nil,
                canGoPrevious: false,
                canGoNext: false,
                isPaused: false,
                canPauseOrResume: true,
                canFinish: true,
                elapsedSeconds: 185,
                elapsedUpdatedAtEpochSeconds: Date().timeIntervalSince1970,
                sessionID: "watch-uitest-session",
                setID: nil,
                quickStartRoutines: []
            )
        }
    }
}
