import Foundation

// MARK: - Commands watch -> phone

enum WatchCommandKind: String, Codable {
    case requestState
    case toggleRestTimer
    case markSetComplete
    case nextSet
    case previousSet
}

/// Keep this deliberately tiny. IDs are strings so we don't couple to SwiftData models.
struct WatchCommand: Codable, Equatable {
    var kind: WatchCommandKind
    var sessionID: String?
    var setID: String?

    init(kind: WatchCommandKind, sessionID: String? = nil, setID: String? = nil) {
        self.kind = kind
        self.sessionID = sessionID
        self.setID = setID
    }
}

// MARK: - State phone -> watch

struct WatchNowPlayingState: Codable, Equatable {
    var isActiveSession: Bool

    var exerciseName: String?
    var setTitle: String?      // e.g. "Set 2 of 4"
    var setDetail: String?     // e.g. "10 reps @ 110 lb"

    var isRestRunning: Bool
    var restRemainingSeconds: Int?

    var canGoPrevious: Bool
    var canGoNext: Bool

    var sessionID: String?
    var setID: String?

    static let inactive = WatchNowPlayingState(
        isActiveSession: false,
        exerciseName: nil,
        setTitle: nil,
        setDetail: nil,
        isRestRunning: false,
        restRemainingSeconds: nil,
        canGoPrevious: false,
        canGoNext: false,
        sessionID: nil,
        setID: nil
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

    static func decodeState(from message: [String: Any]) -> WatchNowPlayingState? {
        guard (message[WatchWireKey.type] as? String) == WatchWireKey.state,
              let data = message[WatchWireKey.data] as? Data
        else { return nil }
        return try? JSONDecoder().decode(WatchNowPlayingState.self, from: data)
    }
}
