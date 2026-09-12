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
    enum RecoveryResolution: Sendable { case pauseAtLastSavedTime, finishAtLastSavedTime }
    struct AppliedCommand: Codable, Equatable, Sendable {
        let id: UUID
        let action: Action
    }
    private(set) var phase: Phase = .idle
    private(set) var accumulated: TimeInterval = 0
    private(set) var anchor: QuickStartClockSample?
    private(set) var revision: Int = 0
    private(set) var appliedCommands: [AppliedCommand] = []

    private static let maximumRecoveryGap: TimeInterval = 12 * 60 * 60
    private static let clockDiscrepancyTolerance: TimeInterval = 5

    func elapsed(at sample: QuickStartClockSample) throws -> TimeInterval {
        try validate(sample)
        guard phase == .running else { return accumulated }
        guard let anchor else { throw QuickStartTimingError.recoveryRequired }
        let wallDelta = sample.wall.timeIntervalSince(anchor.wall)
        let delta: TimeInterval
        if sample.epoch == anchor.epoch {
            let monotonicDelta = sample.uptime - anchor.uptime
            guard monotonicDelta >= 0,
                  abs(wallDelta - monotonicDelta) <= Self.clockDiscrepancyTolerance else {
                throw QuickStartTimingError.recoveryRequired
            }
            delta = monotonicDelta
        } else {
            guard wallDelta >= 0, wallDelta <= Self.maximumRecoveryGap else {
                throw QuickStartTimingError.recoveryRequired
            }
            delta = wallDelta
        }
        let total = accumulated + delta
        guard total.isFinite else { throw QuickStartTimingError.invalidClock }
        return total
    }

    func applying(_ action: Action, id: UUID, expectedRevision: Int,
                  at sample: QuickStartClockSample) throws -> QuickStartTimingState {
        try validate(sample)
        if let previous = appliedCommands.first(where: { $0.id == id }) {
            guard previous.action == action else { throw QuickStartTimingError.commandIdentityReused }
            return self
        }
        guard expectedRevision == revision else { throw QuickStartTimingError.staleRevision }
        if phase == .completed && action == .finish { return self }
        if phase == .paused && action == .pause { return self }
        guard revision < Int.max else { throw QuickStartTimingError.invalidTransition }
        var next = self
        switch (phase, action) {
        case (.idle, .start):
            next.phase = .running
            next.anchor = sample
        case (.running, .pause):
            next.accumulated = try elapsed(at: sample)
            next.anchor = nil
            next.phase = .paused
        case (.paused, .resume):
            next.anchor = sample
            next.phase = .running
        case (.running, .finish):
            next.accumulated = try elapsed(at: sample)
            next.anchor = nil
            next.phase = .completed
        case (.paused, .finish):
            next.anchor = nil
            next.phase = .completed
        default:
            throw QuickStartTimingError.invalidTransition
        }
        next.revision += 1
        next.appliedCommands.append(AppliedCommand(id: id, action: action))
        return next
    }

    func resolvingRecovery(
        _ resolution: RecoveryResolution,
        id: UUID,
        expectedRevision: Int,
        at sample: QuickStartClockSample
    ) throws -> QuickStartTimingState {
        self
    }

    private func validate(_ sample: QuickStartClockSample) throws {
        try validatePersistedState()
        guard sample.wall.timeIntervalSince1970.isFinite,
              sample.uptime.isFinite, sample.uptime >= 0 else {
            throw QuickStartTimingError.invalidClock
        }
    }

    /// Structural validation only; an old valid anchor is retained for clock recovery.
    func validatePersistedState() throws {
        guard accumulated.isFinite, accumulated >= 0, revision >= 0 else {
            throw QuickStartTimingError.invalidClock
        }
        guard revision == appliedCommands.count,
              Set(appliedCommands.map(\.id)).count == appliedCommands.count else {
            throw QuickStartTimingError.invalidTransition
        }
        var recordedPhase: Phase = .idle
        for command in appliedCommands {
            switch (recordedPhase, command.action) {
            case (.idle, .start), (.paused, .resume): recordedPhase = .running
            case (.running, .pause): recordedPhase = .paused
            case (.running, .finish), (.paused, .finish): recordedPhase = .completed
            default: throw QuickStartTimingError.invalidTransition
            }
        }
        guard recordedPhase == phase, phase != .idle || accumulated == 0 else {
            throw QuickStartTimingError.invalidTransition
        }
        guard (phase == .running) == (anchor != nil) else {
            throw QuickStartTimingError.recoveryRequired
        }
        if let anchor {
            guard anchor.wall.timeIntervalSince1970.isFinite,
                  anchor.uptime.isFinite, anchor.uptime >= 0 else {
                throw QuickStartTimingError.invalidClock
            }
        }
    }
}
