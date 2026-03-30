import Foundation
import Combine

/// UI-facing bridge around `RestTimerEngine`.
///
/// This owns the wall-clock ticker, while the engine owns the deterministic state transitions.
@MainActor
final class SessionRestTimerController: ObservableObject {
    static let shared = SessionRestTimerController()

    @Published private(set) var snapshot: RestTimerSnapshot = .inactive
    @Published private(set) var didFinishToken: UUID?

    private var engine = RestTimerEngine()
    private var ticker: Timer?
    private let cuePlayer = WorkoutCuePlayer.shared

    private init() {}

    var isRunning: Bool { snapshot.isRunning }
    var isPaused: Bool { snapshot.isPaused }
    var hasConfiguredTimer: Bool { snapshot.shouldShow }
    var remainingSeconds: Int { snapshot.remainingSeconds }
    var displaySeconds: Int { snapshot.displaySeconds }
    var totalSeconds: Int { snapshot.totalSeconds }

    func configure(seconds: Int, startImmediately: Bool, playStartCue: Bool) {
        didFinishToken = nil

        if startImmediately {
            engine.start(plannedRestSeconds: seconds, now: Date())
            if playStartCue {
                cuePlayer.play(.restStart)
            }
        } else {
            engine.configure(plannedRestSeconds: seconds)
        }

        refresh(now: Date())
    }

    func start(seconds: Int, playStartCue: Bool = true) {
        didFinishToken = nil
        engine.start(plannedRestSeconds: seconds, now: Date())

        if playStartCue {
            cuePlayer.play(.restStart)
        }

        refresh(now: Date())
    }

    func pause() {
        engine.pause(now: Date())
        refresh(now: Date())
    }

    func resume() {
        engine.resume(now: Date())
        refresh(now: Date())
    }

    func reset() {
        engine.reset()
        didFinishToken = nil
        refresh(now: Date())
    }

    func stop() {
        engine.clear()
        didFinishToken = nil
        refresh(now: Date())
    }

    func extend(by seconds: Int) {
        engine.extend(by: seconds, now: Date())
        refresh(now: Date())
    }

    @discardableResult
    func finishAndCaptureElapsedSeconds() -> Int? {
        let elapsed = engine.finish(now: Date())
        didFinishToken = nil
        refresh(now: Date())
        return elapsed
    }

    @discardableResult
    func resolveForNextAction() -> Int? {
        let elapsed = engine.resolveForNextAction(now: Date())
        didFinishToken = nil
        refresh(now: Date())
        return elapsed
    }

    private func refresh(now: Date) {
        let previousSnapshot = snapshot
        let nextSnapshot = engine.snapshot(now: now)
        snapshot = nextSnapshot

        if previousSnapshot.displaySeconds > 3,
           nextSnapshot.displaySeconds <= 3,
           nextSnapshot.displaySeconds > 0,
           nextSnapshot.isRunning {
            cuePlayer.play(.restCountdown)
        }

        if nextSnapshot.shouldPlayCompletionCue {
            didFinishToken = UUID()
            cuePlayer.play(.restEnd)
        }

        if engine.isClockRunning {
            startTickerIfNeeded()
        } else {
            stopTicker()
        }
    }

    private func startTickerIfNeeded() {
        guard ticker == nil else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(now: Date())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
