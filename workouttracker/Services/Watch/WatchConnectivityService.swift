import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {

    static let shared = WatchConnectivityService()

    @Published private(set) var isSupported = WCSession.isSupported()
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var isWatchAppInstalled: Bool = false
    @Published private(set) var isReachable: Bool = false

    private var latestState: WatchNowPlayingState = .inactive
    private var needsFlushLatestState: Bool = false   // ✅ new

    var onCommand: ((WatchCommand) -> Void)?

    private override init() { super.init() }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        refreshFlags(from: session)

        // ✅ If we already had a state queued, try to flush shortly after start.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            flushLatestStateIfNeeded()
        }
    }

    func pushNowPlayingState(_ state: WatchNowPlayingState) {
        latestState = state
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        // If session isn't activated yet, queue a flush.
        guard session.activationState == .activated else {
            needsFlushLatestState = true
            return
        }

        flush(state, via: session)
    }

    func clearNowPlaying() {
        pushNowPlayingState(.inactive)
    }

    private func refreshFlags(from session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
    }

    private func flushLatestStateIfNeeded() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        guard session.activationState == .activated else { return }
        guard needsFlushLatestState || latestState != .inactive else { return }

        needsFlushLatestState = false
        flush(latestState, via: session)
    }

    private func flush(_ state: WatchNowPlayingState, via session: WCSession) {
        // Durable latest snapshot (watch can read it even if not reachable).
        do {
            try session.updateApplicationContext(WatchMessageCodec.encodeState(state))
        } catch {
            // Queue a retry (session might still be warming up).
            needsFlushLatestState = true
            return
        }

        // Live update while watch app is open.
        if session.isReachable {
            session.sendMessage(
                WatchMessageCodec.encodeState(state),
                replyHandler: nil,
                errorHandler: { _ in }
            )
        }
    }

    private func handleIncomingCommand(_ command: WatchCommand, reply: (([String: Any]) -> Void)?) {
        if command.kind == .requestState {
            reply?(WatchMessageCodec.encodeState(latestState))
            return
        }

        onCommand?(command)
        reply?(["ok": true])
    }
}

// MARK: - WCSessionDelegate (phone)

extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.refreshFlags(from: session)
            self.flushLatestStateIfNeeded()   // ✅ key line
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        Task { @MainActor in
            self.refreshFlags(from: session)
            self.flushLatestStateIfNeeded()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshFlags(from: session)
            // ✅ when watch becomes reachable, send a live message too
            self.flushLatestStateIfNeeded()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let command = WatchMessageCodec.decodeCommand(from: message)
        Task { @MainActor in
            if let command {
                self.handleIncomingCommand(command, reply: nil)
            }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String : Any],
                             replyHandler: @escaping ([String : Any]) -> Void) {
        let command = WatchMessageCodec.decodeCommand(from: message)
        Task { @MainActor in
            if let command {
                self.handleIncomingCommand(command, reply: replyHandler)
            } else {
                replyHandler(["ok": false])
            }
        }
    }
}
