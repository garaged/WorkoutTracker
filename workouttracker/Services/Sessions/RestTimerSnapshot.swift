import Foundation

struct RestTimerSnapshot: Equatable {
    enum Mode: Equatable {
        case inactive
        case countdown
        case ready
        case overdue
    }

    let mode: Mode
    let totalSeconds: Int
    let remainingSeconds: Int
    let overdueSeconds: Int
    let displaySeconds: Int
    let isRunning: Bool
    let isPaused: Bool
    let shouldShow: Bool
    let shouldPlayCompletionCue: Bool

    var isInactive: Bool { mode == .inactive }
    var isReady: Bool { mode == .ready }
    var isOverdue: Bool { mode == .overdue }
    var canExtend: Bool { shouldShow }
    var canReset: Bool { shouldShow }

    static let inactive = RestTimerSnapshot(
        mode: .inactive,
        totalSeconds: 0,
        remainingSeconds: 0,
        overdueSeconds: 0,
        displaySeconds: 0,
        isRunning: false,
        isPaused: false,
        shouldShow: false,
        shouldPlayCompletionCue: false
    )
}
