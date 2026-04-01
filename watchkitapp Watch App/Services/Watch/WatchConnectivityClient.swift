import Foundation
import Combine
import WatchConnectivity
import WatchKit

/// Watch-side client.
/// - Sends button commands to iPhone.
/// - Receives "Now Playing" state via app context and live messages.
/// - Derives the rest countdown locally from an absolute end timestamp so the
///   timer remains accurate even when app-context/live updates are sparse.
@MainActor
final class WatchConnectivityClient: NSObject, ObservableObject {

    static let shared = WatchConnectivityClient()

    @Published private(set) var isSupported: Bool = WCSession.isSupported()
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var canSendCommands: Bool = false
    @Published private(set) var nowPlaying: WatchNowPlayingState = .inactive

    private var sourceNowPlaying: WatchNowPlayingState = .inactive
    private var countdownTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    deinit {
        countdownTask?.cancel()
    }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        refreshTransportState(from: session)

        // If we already have a cached context (e.g., watch opens after phone pushed state), apply it.
        let ctx = session.receivedApplicationContext
        if let state = WatchMessageCodec.decodeState(from: ctx) {
            applyReceivedState(state)
        }

        // Ask for a fresh snapshot (fast path when the app is opened).
        requestState()
    }

    func requestState() {
        sendInteractive(.init(kind: .requestState))
    }

    func send(_ command: WatchCommand) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        refreshTransportState(from: session)

        guard canSendCommands else { return }

        session.sendMessage(
            WatchMessageCodec.encodeCommand(command),
            replyHandler: { [weak self] reply in
                guard let self else { return }
                if let state = WatchMessageCodec.decodeState(from: reply) {
                    Task { @MainActor in self.applyReceivedState(state) }
                }
            },
            errorHandler: { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.refreshTransportState(from: session)
                    self.enqueueBackgroundDeliveryIfNeeded(command, via: session)
                }
            }
        )
    }

    private func sendInteractive(_ command: WatchCommand) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        refreshTransportState(from: session)

        guard canSendCommands else { return }

        session.sendMessage(
            WatchMessageCodec.encodeCommand(command),
            replyHandler: { [weak self] reply in
                guard let self else { return }
                if let state = WatchMessageCodec.decodeState(from: reply) {
                    Task { @MainActor in self.applyReceivedState(state) }
                }
            },
            errorHandler: { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.refreshTransportState(from: session)
                }
            }
        )
    }

    private func enqueueBackgroundDeliveryIfNeeded(_ command: WatchCommand, via session: WCSession) {
        guard shouldBackgroundDeliver(command) else { return }
        session.transferUserInfo(WatchMessageCodec.encodeCommand(command))
    }

    private func shouldBackgroundDeliver(_ command: WatchCommand) -> Bool {
        switch command.kind {
        case .requestState:
            return false
        case .toggleRestTimer, .markSetComplete, .nextSet, .previousSet,
             .openCurrentSession, .resumeCurrentSession, .startRoutine:
            return true
        }
    }

    private func refreshTransportState(from session: WCSession) {
        isReachable = session.isReachable
        canSendCommands = session.activationState == .activated
    }

    private func applyReceivedState(_ state: WatchNowPlayingState) {
        sourceNowPlaying = state
        syncTickerForCurrentState()
        recomputeDisplayedState(playFinishHapticIfNeeded: false)
    }

    private func syncTickerForCurrentState() {
        if shouldRunLocalCountdown(for: sourceNowPlaying) {
            startCountdownIfNeeded()
        } else {
            stopCountdown()
        }
    }

    private func shouldRunLocalCountdown(for state: WatchNowPlayingState) -> Bool {
        guard state.isRestRunning, let end = state.restEndsAtEpochSeconds else { return false }
        return end > Date().timeIntervalSince1970
    }

    private func startCountdownIfNeeded() {
        guard countdownTask == nil else { return }
        countdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.recomputeDisplayedState(playFinishHapticIfNeeded: true)
                self.syncTickerForCurrentState()
            }
        }
    }

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func recomputeDisplayedState(playFinishHapticIfNeeded: Bool) {
        let previous = nowPlaying
        var next = sourceNowPlaying

        if next.isRestRunning, let endEpoch = next.restEndsAtEpochSeconds {
            let remaining = max(0, Int(Date(timeIntervalSince1970: endEpoch).timeIntervalSinceNow.rounded(.up)))

            if remaining > 0 {
                next.restRemainingSeconds = remaining
            } else {
                next.isRestRunning = false
                next.restRemainingSeconds = nil
            }
        }

        nowPlaying = next

        if playFinishHapticIfNeeded,
           previous.isRestRunning,
           (previous.restRemainingSeconds ?? 1) > 0,
           !next.isRestRunning {
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityClient: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.refreshTransportState(from: session)
        }
    }

    // These are iOS-only. On watchOS they are unavailable.
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // No-op
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        Task { @MainActor in
            self.refreshTransportState(from: session)
        }
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshTransportState(from: session)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String : Any]) {
        let state = WatchMessageCodec.decodeState(from: applicationContext)
        Task { @MainActor in
            if let state { self.applyReceivedState(state) }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String : Any]) {
        let state = WatchMessageCodec.decodeState(from: message)
        Task { @MainActor in
            if let state { self.applyReceivedState(state) }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String : Any],
                             replyHandler: @escaping ([String : Any]) -> Void) {
        let state = WatchMessageCodec.decodeState(from: message)
        Task { @MainActor in
            if let state { self.applyReceivedState(state) }
            replyHandler(["ok": true])
        }
    }
}
