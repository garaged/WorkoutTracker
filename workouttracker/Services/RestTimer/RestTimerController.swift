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

    /// Changes when the timer naturally reaches 0 (useful for UI auto-dismiss).
    @Published private(set) var didFinishToken: UUID? = nil

    private var endsAt: Date? = nil
    private var announcedCountdownSeconds: Set<Int> = []

    private let cuePlayer = WorkoutCuePlayer.shared
    private let notificationScheduler = RestTimerNotificationScheduler.shared
    private let prefs = UserPreferences.shared

    private init() {}

    var hasConfiguredTimer: Bool {
        totalSeconds > 0 && remainingSeconds > 0
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
        guard isRunning, let end = endsAt else { return }

        remainingSeconds = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        isRunning = false
        endsAt = nil
        stopTicking()
        notificationScheduler.cancelActiveRestNotification()
    }

    func resume() {
        guard !isRunning, remainingSeconds > 0 else { return }

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

    func toggle(defaultSeconds: Int) {
        if isRunning {
            stop()
        } else {
            start(seconds: defaultSeconds)
        }
    }

    /// Adjust remaining time while running (supports negative values).
    func extend(by seconds: Int) {
        let delta = max(1, seconds)
        announcedCountdownSeconds.removeAll()
        didFinishToken = nil

        if isRunning, let end = endsAt {
            let minEnd = Date().addingTimeInterval(1)
            endsAt = max(end.addingTimeInterval(TimeInterval(delta)), minEnd)
            scheduleRestFinishedNotification()
            tick()
            return
        }

        let resumedSeconds = max(1, remainingSeconds + delta)
        totalSeconds = max(totalSeconds, resumedSeconds)
        remainingSeconds = resumedSeconds
        endsAt = Date().addingTimeInterval(TimeInterval(resumedSeconds))
        isRunning = true
        scheduleRestFinishedNotification()
        startTicking()
        tick()
    }

    // MARK: - Internals

    private func scheduleRestFinishedNotification() {
        guard let end = endsAt else {
            notificationScheduler.cancelActiveRestNotification()
            return
        }

        notificationScheduler.scheduleRestFinished(
            after: end.timeIntervalSinceNow,
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
        guard let end = endsAt else { return }

        let remaining = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        if remaining != remainingSeconds {
            remainingSeconds = remaining
        }

        if remaining == 3, !announcedCountdownSeconds.contains(remaining) {
            announcedCountdownSeconds.insert(remaining)
            cuePlayer.play(.restCountdown)
        }

        if remaining <= 0 {
            let lateness = max(0, Date().timeIntervalSince(end))

            isRunning = false
            endsAt = nil
            stopTicking()
            notificationScheduler.cancelActiveRestNotification()
            didFinishToken = UUID()

            // If the timer expired while the app was backgrounded for a while,
            // the local notification already handled the user-facing cue.
            if lateness < 2.0, UIApplication.shared.applicationState == .active {
                cuePlayer.play(.restEnd)
                Haptics.success()
            }
        }
    }
}
