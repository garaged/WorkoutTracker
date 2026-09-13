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
        styleRaw = payload.styleRaw
        style = payload.style
        phase = payload.timing.phase
        do {
            timingStatus = .elapsed(try payload.timing.elapsed(at: sample))
        } catch let error as QuickStartTimingError where error == .recoveryRequired {
            timingStatus = .recoveryRequired
        } catch {
            throw error
        }
    }

    var primaryAction: PrimaryAction? {
        if timingStatus == .recoveryRequired {
            return .resolveRecovery
        }
        return switch phase {
        case .idle: nil
        case .running: .pause
        case .paused: .resume
        case .completed: .done
        }
    }
}
