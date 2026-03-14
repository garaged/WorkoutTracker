import Foundation

/// Pure timer domain logic.
///
/// The engine never owns a wall clock or UI timer. All transitions are driven by explicit
/// `Date` input so unit tests can advance time deterministically.
struct RestTimerEngine: Equatable {
    private(set) var plannedRestSeconds: Int = 0
    private(set) var startedAt: Date?
    private(set) var extendedSeconds: Int = 0
    private(set) var cuePlayed = false
    private(set) var pausedDisplaySeconds: Int?

    var totalSeconds: Int {
        max(0, plannedRestSeconds + extendedSeconds)
    }

    var isClockRunning: Bool {
        startedAt != nil
    }

    var hasConfiguredTimer: Bool {
        totalSeconds > 0 || startedAt != nil || pausedDisplaySeconds != nil
    }

    mutating func configure(plannedRestSeconds: Int) {
        let normalized = max(0, plannedRestSeconds)
        self.plannedRestSeconds = normalized
        extendedSeconds = 0
        startedAt = nil
        pausedDisplaySeconds = nil
        cuePlayed = false

        if normalized == 0 {
            clear()
        }
    }

    mutating func start(plannedRestSeconds: Int, now: Date) {
        let normalized = max(0, plannedRestSeconds)
        guard normalized > 0 else {
            clear()
            return
        }

        self.plannedRestSeconds = normalized
        extendedSeconds = 0
        startedAt = now
        pausedDisplaySeconds = nil
        cuePlayed = false
    }

    mutating func start(now: Date) {
        guard totalSeconds > 0 else {
            clear()
            return
        }

        startedAt = now
        pausedDisplaySeconds = nil
        cuePlayed = false
    }

    mutating func pause(now: Date) {
        guard startedAt != nil else { return }
        let display = currentDisplaySeconds(now: now)
        guard display > 0 else { return }

        pausedDisplaySeconds = display
        startedAt = nil
    }

    mutating func resume(now: Date) {
        guard let pausedDisplaySeconds, pausedDisplaySeconds > 0 else { return }

        plannedRestSeconds = pausedDisplaySeconds
        extendedSeconds = 0
        startedAt = now
        self.pausedDisplaySeconds = nil
        cuePlayed = false
    }

    mutating func reset() {
        guard totalSeconds > 0 else {
            clear()
            return
        }

        startedAt = nil
        pausedDisplaySeconds = nil
        cuePlayed = false
    }

    mutating func extend(by seconds: Int, now: Date) {
        guard hasConfiguredTimer else { return }

        if let pausedDisplaySeconds {
            let adjusted = max(0, pausedDisplaySeconds + seconds)
            self.pausedDisplaySeconds = adjusted == 0 ? nil : adjusted
            plannedRestSeconds = adjusted
            extendedSeconds = 0
            cuePlayed = false
            if adjusted == 0 {
                clear()
            }
            return
        }

        let updatedTotal = max(0, totalSeconds + seconds)
        plannedRestSeconds = updatedTotal
        extendedSeconds = 0

        if updatedTotal == 0 {
            clear()
            return
        }

        let newDisplay = currentDisplaySeconds(now: now)
        cuePlayed = newDisplay <= 0
    }

    mutating func resolveForNextAction(now: Date) {
        _ = now
        clear()
    }

    mutating func clear() {
        plannedRestSeconds = 0
        startedAt = nil
        extendedSeconds = 0
        pausedDisplaySeconds = nil
        cuePlayed = false
    }

    mutating func snapshot(now: Date) -> RestTimerSnapshot {
        guard hasConfiguredTimer else { return .inactive }

        let display = currentDisplaySeconds(now: now)
        let remaining = max(display, 0)
        let overdue = max(-display, 0)

        let mode: RestTimerSnapshot.Mode
        var shouldPlayCompletionCue = false

        if startedAt == nil && pausedDisplaySeconds == nil {
            mode = .countdown
        } else if display > 0 {
            mode = .countdown
        } else if display == 0 {
            mode = .ready
            if !cuePlayed {
                shouldPlayCompletionCue = true
                cuePlayed = true
            }
        } else {
            mode = .overdue
            if !cuePlayed {
                shouldPlayCompletionCue = true
                cuePlayed = true
            }
        }

        return RestTimerSnapshot(
            mode: mode,
            totalSeconds: totalSeconds,
            remainingSeconds: remaining,
            overdueSeconds: overdue,
            displaySeconds: display,
            isRunning: startedAt != nil && display > 0,
            isPaused: pausedDisplaySeconds != nil,
            shouldShow: true,
            shouldPlayCompletionCue: shouldPlayCompletionCue
        )
    }

    private func currentDisplaySeconds(now: Date) -> Int {
        if let pausedDisplaySeconds {
            return pausedDisplaySeconds
        }

        guard let startedAt else {
            return totalSeconds
        }

        let elapsed = max(0, Int(now.timeIntervalSince(startedAt).rounded(.down)))
        return totalSeconds - elapsed
    }
}
