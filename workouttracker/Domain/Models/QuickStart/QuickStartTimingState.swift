import Foundation

struct QuickStartClockSample: Codable, Equatable, Sendable {
    let wall: Date
    let uptime: TimeInterval
    let epoch: UUID
}

enum QuickStartTimingError: Error, Equatable {
    case staleRevision
    case commandIdentityReused
    case invalidTransition
    case invalidClock
    case recoveryRequired
}

struct QuickStartTimingState: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable { case idle, running, paused, completed }
    enum Action: String, Codable, Sendable { case start, pause, resume, finish }
    struct AppliedCommand: Codable, Equatable, Sendable {
        let id: UUID
        let action: Action
    }
    private(set) var phase: Phase = .idle
    private(set) var accumulated: TimeInterval = 0
    private(set) var anchor: QuickStartClockSample?
    private(set) var revision: Int = 0
    private(set) var appliedCommands: [AppliedCommand] = []

    func elapsed(at sample: QuickStartClockSample) throws -> TimeInterval {
        accumulated
    }

    func applying(_ action: Action, id: UUID, expectedRevision: Int,
                  at sample: QuickStartClockSample) throws -> QuickStartTimingState {
        self
    }
}
