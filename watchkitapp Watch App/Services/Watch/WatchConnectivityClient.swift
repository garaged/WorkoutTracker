import Foundation
import Combine
import WatchConnectivity
import WatchKit

/// Watch-side client.
/// - Sends button commands to iPhone.
/// - Receives "Now Playing" state via app context and live messages.
/// - Derives the rest countdown locally from an absolute end timestamp so the
///   timer remains accurate even when app-context/live updates are sparse.
/// - Derives tracked-activity elapsed time locally from a baseline timestamp so
///   watch controls feel live even before the next mirrored state arrives.
@MainActor
final class WatchConnectivityClient: NSObject, ObservableObject {

    static let shared = WatchConnectivityClient()

    @Published private(set) var isSupported: Bool = WCSession.isSupported()
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var canSendCommands: Bool = false
    @Published private(set) var nowPlaying: WatchNowPlayingState = .inactive
    @Published private(set) var lastStateReceivedAt: Date?

    private var sourceNowPlaying: WatchNowPlayingState = .inactive
    private var lastKnownActiveSessionState: WatchNowPlayingState?
    private var countdownTask: Task<Void, Never>?
    private let recoveryEvaluator = WatchRecoveryEvaluator(recoveryGraceInterval: 20)
    private var activeUITestSeed: WatchUITestSeed?

    private override init() {
        super.init()
    }

    deinit {
        countdownTask?.cancel()
    }

    var hasRecoverableNowPlayingSession: Bool {
        recoveryEvaluator.hasRecoverableNowPlayingSession(
            displayedIsActiveSession: nowPlaying.isActiveSession,
            isRecoveringRecentSession: isRecoveringRecentSession
        )
    }

    var isRecoveringRecentSession: Bool {
        recoveryEvaluator.isRecoveringRecentSession(
            sourceIsActiveSession: sourceNowPlaying.isActiveSession,
            canSendCommands: canSendCommands,
            isReachable: isReachable,
            lastKnownActiveSession: lastKnownActiveSessionState?.isActiveSession == true,
            lastStateReceivedAt: lastStateReceivedAt
        )
    }

    var transportStatusText: String? {
        switch recoveryEvaluator.transportStatus(
            isRecoveringRecentSession: isRecoveringRecentSession,
            canSendCommands: canSendCommands,
            isReachable: isReachable
        ) {
        case .reconnecting:
            return String(localized: "watch.transport.status.reconnecting", defaultValue: "Reconnecting to iPhone")
        case .phoneUnavailable:
            return String(localized: "watch.now_playing.status.phone_unavailable", defaultValue: "Phone unavailable")
        case .phoneClosed:
            return String(localized: "watch.now_playing.status.phone_closed", defaultValue: "Phone app closed — commands may take a moment")
        case nil:
            return nil
        }
    }

    var transportStatusSymbol: String {
        switch recoveryEvaluator.transportStatus(
            isRecoveringRecentSession: isRecoveringRecentSession,
            canSendCommands: canSendCommands,
            isReachable: isReachable
        ) {
        case .reconnecting:
            return "arrow.triangle.2.circlepath"
        case .phoneUnavailable:
            return "iphone.slash"
        case .phoneClosed:
            return "iphone.gen2.radiowaves.left.and.right"
        case nil:
            return "checkmark.circle"
        }
    }

    var trackedActivityStatusText: String {
        switch recoveryEvaluator.trackedActivityStatus(
            isPaused: nowPlaying.isPaused,
            isRecoveringRecentSession: isRecoveringRecentSession
        ) {
        case .paused:
            return String(localized: "watch.now_playing.state.paused", defaultValue: "Paused")
        case .pausedReconnecting:
            return String(localized: "watch.now_playing.state.paused_reconnecting", defaultValue: "Paused — reconnecting")
        case .liveReconnecting:
            return String(localized: "watch.now_playing.state.live_reconnecting", defaultValue: "Active — reconnecting")
        case .trackingLiveOnPhone:
            return String(localized: "watch.now_playing.state.tracking_live_on_phone", defaultValue: "Tracking live on iPhone")
        }
    }

    private var isTransportHealthy: Bool {
        recoveryEvaluator.isTransportHealthy(canSendCommands: canSendCommands, isReachable: isReachable)
    }

    func start() {
        if let seed = WatchUITestSeed.current {
            applyUITestSeed(seed)
            return
        }

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        refreshTransportState(from: session)

        let ctx = session.receivedApplicationContext
        if let state = WatchMessageCodec.decodeState(from: ctx) {
            applyReceivedState(state)
        }

        requestState()
    }

    func requestState() {
        sendInteractive(.init(kind: .requestState))
    }

    func send(_ command: WatchCommand) {
        if activeUITestSeed != nil { return }
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


    func applyUITestSeed(_ seed: WatchUITestSeed) {
        activeUITestSeed = seed
        isSupported = true
        isReachable = seed.isReachable
        canSendCommands = seed.canSendCommands
        lastStateReceivedAt = seed.lastStateReceivedAt
        sourceNowPlaying = seed.nowPlayingState
        lastKnownActiveSessionState = seed.nowPlayingState.isActiveSession ? seed.nowPlayingState : nil
        syncTickerForCurrentState()
        recomputeDisplayedState(playFinishHapticIfNeeded: false)
    }

    private func sendInteractive(_ command: WatchCommand) {
        if activeUITestSeed != nil { return }
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
             .openCurrentSession, .resumeCurrentSession, .startRoutine,
             .startTrackedActivity, .resumeCurrentTrackedActivity,
             .pauseTrackedActivity, .resumeTrackedActivity, .finishTrackedActivity:
            return true
        }
    }

    private func refreshTransportState(from session: WCSession) {
        isReachable = session.isReachable
        canSendCommands = session.activationState == .activated
    }

    private func applyReceivedState(_ state: WatchNowPlayingState) {
        sourceNowPlaying = state
        lastStateReceivedAt = Date()

        if state.isActiveSession {
            lastKnownActiveSessionState = state
        } else if isTransportHealthy {
            lastKnownActiveSessionState = nil
        }

        syncTickerForCurrentState()
        recomputeDisplayedState(playFinishHapticIfNeeded: false)
    }

    private func syncTickerForCurrentState() {
        if recoveryEvaluator.shouldRunLocalTicker(
            for: .init(
                isActiveSession: sourceNowPlaying.isActiveSession,
                isTrackedActivitySession: sourceNowPlaying.isTrackedActivitySession,
                isPaused: sourceNowPlaying.isPaused,
                isRestRunning: sourceNowPlaying.isRestRunning,
                restEndsAtEpochSeconds: sourceNowPlaying.restEndsAtEpochSeconds,
                elapsedSeconds: sourceNowPlaying.elapsedSeconds,
                elapsedUpdatedAtEpochSeconds: sourceNowPlaying.elapsedUpdatedAtEpochSeconds
            ),
            isRecoveringRecentSession: isRecoveringRecentSession
        ) {
            startCountdownIfNeeded()
        } else {
            stopCountdown()
        }
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

    private func displayedStateSource() -> WatchNowPlayingState {
        if sourceNowPlaying.isActiveSession {
            return sourceNowPlaying
        }

        if isRecoveringRecentSession, let lastKnownActiveSessionState {
            return lastKnownActiveSessionState
        }

        return sourceNowPlaying
    }

    private func recomputeDisplayedState(playFinishHapticIfNeeded: Bool) {
        let previous = nowPlaying
        var next = displayedStateSource()

        if next.isRestRunning, let endEpoch = next.restEndsAtEpochSeconds {
            let remaining = max(0, Int(Date(timeIntervalSince1970: endEpoch).timeIntervalSinceNow.rounded(.up)))

            if remaining > 0 {
                next.restRemainingSeconds = remaining
            } else {
                next.isRestRunning = false
                next.restRemainingSeconds = nil
            }
        }

        if next.isTrackedActivitySession,
           next.isActiveSession,
           !next.isPaused,
           let baselineSeconds = next.elapsedSeconds,
           let baselineEpoch = next.elapsedUpdatedAtEpochSeconds {
            let delta = max(0, Int(Date().timeIntervalSince1970 - baselineEpoch))
            next.elapsedSeconds = max(0, baselineSeconds + delta)
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

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
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
