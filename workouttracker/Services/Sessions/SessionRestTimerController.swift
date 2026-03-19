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

    private init() {}

    var isRunning: Bool { snapshot.isRunning }
    var hasConfiguredTimer: Bool { snapshot.shouldShow }
    var remainingSeconds: Int { snapshot.remainingSeconds }
    var totalSeconds: Int { snapshot.totalSeconds }

    func configure(seconds: Int, startImmediately: Bool, playStartCue: Bool) {
        _ = playStartCue // Cue playback stays outside this domain/controller PR.

        if startImmediately {
            engine.start(plannedRestSeconds: seconds, now: Date())
        } else {
            engine.configure(plannedRestSeconds: seconds)
        }

        refresh(now: Date())
    }

    func start(seconds: Int) {
        engine.start(plannedRestSeconds: seconds, now: Date())
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

    func resolveForNextAction() {
        engine.resolveForNextAction(now: Date())
        didFinishToken = nil
        refresh(now: Date())
    }

    private func refresh(now: Date) {
        let nextSnapshot = engine.snapshot(now: now)
        snapshot = nextSnapshot

        if nextSnapshot.shouldPlayCompletionCue {
            didFinishToken = UUID()
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
