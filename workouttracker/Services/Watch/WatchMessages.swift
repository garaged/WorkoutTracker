import Foundation

// MARK: - Commands watch -> phone

enum WatchCommandKind: String, Codable {
    case requestState
    case toggleRestTimer
    case markSetComplete
    case nextSet
    case previousSet
    case openCurrentSession
    case resumeCurrentSession
    case startRoutine
    case startTrackedActivity
    case resumeCurrentTrackedActivity
    case pauseTrackedActivity
    case resumeTrackedActivity
    case finishTrackedActivity
}

/// Keep this deliberately tiny. IDs are strings so we don't couple to SwiftData models.
struct WatchCommand: Codable, Equatable {
    var kind: WatchCommandKind
    var sessionID: String?
    var setID: String?
    var routineID: String?
    var trackedActivityKindRaw: String?
    var activityEnvironmentRaw: String?

    init(
        kind: WatchCommandKind,
        sessionID: String? = nil,
        setID: String? = nil,
        routineID: String? = nil,
        trackedActivityKindRaw: String? = nil,
        activityEnvironmentRaw: String? = nil
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.setID = setID
        self.routineID = routineID
        self.trackedActivityKindRaw = trackedActivityKindRaw
        self.activityEnvironmentRaw = activityEnvironmentRaw
    }
}

struct WatchRoutineSummary: Codable, Equatable, Identifiable {
    var id: String
    var name: String
}

enum WatchNowPlayingPresentationKind: String, Codable, Equatable {
    case inactive
    case strengthSession
    case trackedActivity
}

// MARK: - State phone -> watch

struct WatchNowPlayingState: Codable, Equatable {
    var presentationKind: WatchNowPlayingPresentationKind
    var isActiveSession: Bool

    var exerciseName: String?
    var setTitle: String?      // e.g. "Set 2 of 4" or "Outdoor"
    var setDetail: String?     // e.g. "10 reps @ 110 lb" or user notes

    var isRestRunning: Bool
    var restRemainingSeconds: Int?
    /// Absolute end timestamp used by the watch to derive its own countdown.
    var restEndsAtEpochSeconds: TimeInterval?

    var canGoPrevious: Bool
    var canGoNext: Bool
    var isPaused: Bool
    var canPauseOrResume: Bool
    var canFinish: Bool
    var elapsedSeconds: Int?
    /// Timestamp paired with elapsedSeconds so watch can derive a local timer.
    var elapsedUpdatedAtEpochSeconds: TimeInterval?

    var sessionID: String?
    var setID: String?
    var quickStartRoutines: [WatchRoutineSummary]

    var isStrengthSession: Bool { presentationKind == .strengthSession }
    var isTrackedActivitySession: Bool { presentationKind == .trackedActivity }

    static let inactive = WatchNowPlayingState(
        presentationKind: .inactive,
        isActiveSession: false,
        exerciseName: nil,
        setTitle: nil,
        setDetail: nil,
        isRestRunning: false,
        restRemainingSeconds: nil,
        restEndsAtEpochSeconds: nil,
        canGoPrevious: false,
        canGoNext: false,
        isPaused: false,
        canPauseOrResume: false,
        canFinish: false,
        elapsedSeconds: nil,
        elapsedUpdatedAtEpochSeconds: nil,
        sessionID: nil,
        setID: nil,
        quickStartRoutines: []
    )
}

// MARK: - WC dictionary codec

enum WatchWireKey {
    static let type = "type"
    static let data = "data"

    static let command = "command"
    static let state = "state"
}

enum WatchMessageCodec {
    static func encodeCommand(_ command: WatchCommand) -> [String: Any] {
        let data = (try? JSONEncoder().encode(command)) ?? Data()
        return [WatchWireKey.type: WatchWireKey.command, WatchWireKey.data: data]
    }

    static func encodeState(_ state: WatchNowPlayingState) -> [String: Any] {
        let data = (try? JSONEncoder().encode(state)) ?? Data()
        return [WatchWireKey.type: WatchWireKey.state, WatchWireKey.data: data]
    }

    static func decodeCommand(from message: [String: Any]) -> WatchCommand? {
        guard (message[WatchWireKey.type] as? String) == WatchWireKey.command,
              let data = message[WatchWireKey.data] as? Data
        else { return nil }
        return try? JSONDecoder().decode(WatchCommand.self, from: data)
    }

    nonisolated static func decodeState(from message: [String: Any]) -> WatchNowPlayingState? {
        let typeKey = "type"
        let dataKey = "data"
        let stateValue = "state"

        guard (message[typeKey] as? String) == stateValue,
              let data = message[dataKey] as? Data
        else { return nil }
        return try? JSONDecoder().decode(WatchNowPlayingState.self, from: data)
    }
}
