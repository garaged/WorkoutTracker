import Foundation
import Combine

@MainActor
final class RestTimerController: ObservableObject {

    static let shared = RestTimerController()

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var totalSeconds: Int = 0
    @Published private(set) var remainingSeconds: Int = 0

    /// Changes when the timer naturally reaches 0 (useful for UI auto-dismiss).
    @Published private(set) var didFinishToken: UUID? = nil

    private var endsAt: Date? = nil
    private var tickTimer: Timer? = nil

    private init() {}

    func start(seconds: Int) {
        let s = max(1, seconds)
        totalSeconds = s
        remainingSeconds = s
        isRunning = true
        endsAt = Date().addingTimeInterval(TimeInterval(s))
        startTicking()
        tick() // immediate UI update
    }

    func stop() {
        isRunning = false
        endsAt = nil
        stopTicking()
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
        guard isRunning, let end = endsAt else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(seconds))

        // Clamp so it doesn't go "past" now.
        let minEnd = Date().addingTimeInterval(1)
        endsAt = max(newEnd, minEnd)
        tick()
    }

    // MARK: - Internals

    private func startTicking() {
        stopTicking()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        guard isRunning, let end = endsAt else { return }

        let remaining = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        if remaining != remainingSeconds {
            remainingSeconds = remaining
        }

        if remaining <= 0 {
            isRunning = false
            endsAt = nil
            stopTicking()
            didFinishToken = UUID()
        }
    }
}
