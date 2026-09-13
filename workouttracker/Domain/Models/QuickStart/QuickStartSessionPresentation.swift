import Foundation

struct QuickStartSessionPresentation: Equatable, Sendable {
    enum TimingStatus: Equatable, Sendable {
        case elapsed(TimeInterval)
        case recoveryRequired
    }

    enum PrimaryAction: Equatable, Sendable {
        case pause
        case resume
        case done
        case resolveRecovery
    }

    let styleRaw: String
    let style: QuickStartStyle?
    let phase: QuickStartTimingState.Phase
    let timingStatus: TimingStatus

    init(payload: QuickStartTimingPayload, at sample: QuickStartClockSample) throws {
        styleRaw = ""
        style = nil
        phase = .idle
        timingStatus = .elapsed(0)
    }

    var primaryAction: PrimaryAction? { nil }
}
