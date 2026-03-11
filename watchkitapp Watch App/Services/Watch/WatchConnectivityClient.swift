import Foundation
import Combine
import WatchConnectivity

/// Watch-side client.
/// - Sends button commands to iPhone.
/// - Receives "Now Playing" state via app context and live messages.
@MainActor
final class WatchConnectivityClient: NSObject, ObservableObject {

    static let shared = WatchConnectivityClient()

    @Published private(set) var isSupported: Bool = WCSession.isSupported()
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var nowPlaying: WatchNowPlayingState = .inactive

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        isReachable = session.isReachable

        // If we already have a cached context (e.g., watch opens after phone pushed state), apply it.
        let ctx = session.receivedApplicationContext
        if let state = WatchMessageCodec.decodeState(from: ctx) {
            nowPlaying = state
        }

        // Ask for a fresh snapshot (fast path when the app is opened).
        requestState()
    }

    func requestState() {
        send(WatchCommand(kind: .requestState))
    }

    func send(_ command: WatchCommand) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        guard session.isReachable else {
            // v1: don't queue remote actions. Late actions feel worse than missed actions.
            return
        }

        session.sendMessage(
            WatchMessageCodec.encodeCommand(command),
            replyHandler: { [weak self] reply in
                guard let self else { return }
                if let state = WatchMessageCodec.decodeState(from: reply) {
                    Task { @MainActor in self.nowPlaying = state }
                }
            },
            errorHandler: { _ in }
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityClient: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
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
            self.isReachable = session.isReachable
        }
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String : Any]) {
        let state = WatchMessageCodec.decodeState(from: applicationContext)
        Task { @MainActor in
            if let state { self.nowPlaying = state }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String : Any]) {
        let state = WatchMessageCodec.decodeState(from: message)
        Task { @MainActor in
            if let state { self.nowPlaying = state }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String : Any],
                             replyHandler: @escaping ([String : Any]) -> Void) {
        let state = WatchMessageCodec.decodeState(from: message)
        Task { @MainActor in
            if let state { self.nowPlaying = state }
            replyHandler(["ok": true])
        }
    }
}
