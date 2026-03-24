import Foundation
import Combine
import UIKit

@MainActor
final class RestTimerController: ObservableObject {

    static let shared = RestTimerController()

    private var tickerTask: Task<Void, Never>?

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var totalSeconds: Int = 0
    @Published private(set) var remainingSeconds: Int = 0

    /// Changes once when the timer first reaches / crosses 0.
    /// This is useful for one-time cues, but should not auto-stop the timer.
    @Published private(set) var didFinishToken: UUID? = nil

    private var endsAt: Date? = nil
    private var announcedCountdownSeconds: Set<Int> = []

    private let cuePlayer = WorkoutCuePlayer.shared
    private let notificationScheduler = RestTimerNotificationScheduler.shared
    private let prefs = UserPreferences.shared

    private init() {}

    var hasConfiguredTimer: Bool {
        totalSeconds > 0
    }

    /// Planned rest plus any overdue time already spent.
    /// Example:
    /// - planned 60, remaining 25  -> elapsed 35
    /// - planned 60, remaining -15 -> elapsed 75
    var actualElapsedSeconds: Int {
        guard totalSeconds > 0 else { return 0 }
        return max(0, totalSeconds - remainingSeconds)
    }

    var isOverdue: Bool {
        totalSeconds > 0 && remainingSeconds < 0
    }

    /// Absolute end time for a running timer. Views/companions should prefer this
    /// over a transient countdown integer so they can reconstruct remaining time.
    var activeEndDate: Date? {
        endsAt
    }

    func start(seconds: Int, playStartCue: Bool = true) {
        let s = max(1, seconds)
        totalSeconds = s
        remainingSeconds = s
        isRunning = true
        didFinishToken = nil
        endsAt = Date().addingTimeInterval(TimeInterval(s))
        announcedCountdownSeconds.removeAll()
        scheduleRestFinishedNotification()
        startTicking()

        if playStartCue {
            cuePlayer.play(.restStart)
        }

        tick() // immediate UI update
    }

    /// Prepares a timer without forcing every caller to know how controller state is stored.
    func configure(seconds: Int, startImmediately: Bool, playStartCue: Bool = true) {
        let s = max(1, seconds)
        totalSeconds = s
        remainingSeconds = s
        announcedCountdownSeconds.removeAll()
        didFinishToken = nil

        if startImmediately {
            start(seconds: s, playStartCue: playStartCue)
        } else {
            isRunning = false
            endsAt = nil
            stopTicking()
            notificationScheduler.cancelActiveRestNotification()
        }
    }

    func pause() {
        guard isRunning else { return }

        remainingSeconds = currentRemainingSeconds(at: Date())
        isRunning = false
        endsAt = nil
        stopTicking()
        notificationScheduler.cancelActiveRestNotification()
    }

    func resume() {
        guard !isRunning, totalSeconds > 0 else { return }

        endsAt = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        scheduleRestFinishedNotification()
        startTicking()
        tick()
    }

    func reset() {
        isRunning = false
        endsAt = nil
        stopTicking()
        notificationScheduler.cancelActiveRestNotification()
        remainingSeconds = totalSeconds
        announcedCountdownSeconds.removeAll()
        didFinishToken = nil
    }

    func stop() {
        isRunning = false
        endsAt = nil
        stopTicking()
        notificationScheduler.cancelActiveRestNotification()
        totalSeconds = 0
        remainingSeconds = 0
        announcedCountdownSeconds.removeAll()
        didFinishToken = nil
    }

    /// Returns the actual rest used, including overdue time, before clearing timer state.
    @discardableResult
    func stopAndCaptureElapsedSeconds() -> Int {
        let elapsed = actualElapsedSeconds
        stop()
        return elapsed
    }

    func toggle(defaultSeconds: Int) {
        if isRunning {
            stop()
        } else {
            start(seconds: defaultSeconds)
        }
    }

    /// Adjust remaining time while running.
    /// Negative values move the timer closer to / deeper past zero.
    func extend(by seconds: Int) {
        guard isRunning, let end = endsAt else { return }
        endsAt = end.addingTimeInterval(TimeInterval(seconds))
        scheduleRestFinishedNotification()
        tick()
    }

    // MARK: - Internals

    private func scheduleRestFinishedNotification() {
        guard let end = endsAt else {
            notificationScheduler.cancelActiveRestNotification()
            return
        }

        let secondsUntilEnd = end.timeIntervalSinceNow
        guard secondsUntilEnd > 0 else {
            notificationScheduler.cancelActiveRestNotification()
            return
        }

        notificationScheduler.scheduleRestFinished(
            after: secondsUntilEnd,
            soundEnabled: prefs.restSoundCuesEnabled
        )
    }

    private func startTicking() {
        stopTicking()
        tickerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                handleTickerFired()
            }
        }
    }

    private func stopTicking() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func handleTickerFired() {
        guard isRunning else { return }
        tick()
    }

    private func tick() {
        guard endsAt != nil else { return }

        let remaining = currentRemainingSeconds(at: Date())
        if remaining != remainingSeconds {
            remainingSeconds = remaining
        }

        if remaining == 3, !announcedCountdownSeconds.contains(remaining) {
            announcedCountdownSeconds.insert(remaining)
            cuePlayer.play(.restCountdown)
        }

        if remaining <= 0 {
            notificationScheduler.cancelActiveRestNotification()

            if didFinishToken == nil {
                didFinishToken = UUID()

                if UIApplication.shared.applicationState == .active {
                    cuePlayer.play(.restEnd)
                    Haptics.success()
                }
            }
        }
    }

    private func currentRemainingSeconds(at now: Date) -> Int {
        guard let end = endsAt else { return remainingSeconds }

        let delta = end.timeIntervalSince(now)

        if delta > 0 {
            return Int(delta.rounded(.up))
        }

        if delta < 0 {
            return -Int(abs(delta).rounded(.down))
        }

        return 0
    }
}
