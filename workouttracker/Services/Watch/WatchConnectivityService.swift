import Foundation
import Combine
import WatchConnectivity
import os

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {

    static let shared = WatchConnectivityService()

    @Published private(set) var isSupported = WCSession.isSupported()
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var isWatchAppInstalled: Bool = false
    @Published private(set) var isReachable: Bool = false

    private var latestState: WatchNowPlayingState = .inactive
    private var needsFlushLatestState: Bool = false

    private let log = Logger(subsystem: "garaged.org.workouttracker", category: "WatchConnectivity")

    var onCommand: ((WatchCommand) -> Void)?

    private override init() { super.init() }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        refreshFlags(from: session)

        // Small delayed flush to cover "activation finishes right after start()".
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            self.flushLatestStateIfNeeded()
        }
    }

    func pushNowPlayingState(_ state: WatchNowPlayingState) {
        latestState = state
        guard WCSession.isSupported() else { return }

        let session = WCSession.default

        // If not activated yet, queue.
        guard session.activationState == .activated else {
            needsFlushLatestState = true
            log.debug("Queued state flush; activationState=\(String(describing: session.activationState.rawValue))")
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
        log.debug("Flags paired=\(self.isPaired) installed=\(self.isWatchAppInstalled) reachable=\(self.isReachable)")
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
        guard session.isPaired else { return }
        guard session.isWatchAppInstalled else {
            needsFlushLatestState = true
            return
        }
        do {
            try session.updateApplicationContext(WatchMessageCodec.encodeState(state))
            log.debug("updateApplicationContext OK; active=\(state.isActiveSession)")
        } catch {
            needsFlushLatestState = true
            log.error("updateApplicationContext failed: \(String(describing: error))")
            return
        }

        // Live push only when reachable (watch app open + phone app active).
        if session.isReachable {
            session.sendMessage(WatchMessageCodec.encodeState(state),
                                replyHandler: nil,
                                errorHandler: { err in
                self.log.error("sendMessage failed: \(String(describing: err))")
            })
        }
    }

    private func handleIncomingCommand(_ command: WatchCommand, reply: (([String: Any]) -> Void)?) {
        if command.kind == .requestState {
            reply?(WatchMessageCodec.encodeState(latestState))
            return
        }
        onCommand?(command)
        reply?( ["ok": true] )
    }
}

extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.refreshFlags(from: session)
            self.flushLatestStateIfNeeded()
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
            self.flushLatestStateIfNeeded()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let command = WatchMessageCodec.decodeCommand(from: message)
        Task { @MainActor in
            if let command { self.handleIncomingCommand(command, reply: nil) }
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

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        let command = WatchMessageCodec.decodeCommand(from: userInfo)
        Task { @MainActor in
            if let command {
                self.handleIncomingCommand(command, reply: nil)
            }
        }
    }
}
