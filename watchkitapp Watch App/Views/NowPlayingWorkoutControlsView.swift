import SwiftUI

struct NowPlayingWorkoutControlsView: View {

    let onClose: () -> Void
    @StateObject private var client = WatchConnectivityClient.shared
    private let presentation = WatchPresentationEvaluator()

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            statusRow
            controlsRow
            footerRow
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("Watch.NowPlaying.Screen")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "watch.now_playing.action.back", defaultValue: "Back"), action: onClose)
            }
        }
        .onAppear {
            client.start()
            client.requestState()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            if showsTrackedActivityControls || client.nowPlaying.isActiveSession {
                Text(client.nowPlaying.exerciseName ?? String(localized: "watch.now_playing.fallback.workout", defaultValue: "Workout"))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let subtitle = client.nowPlaying.setTitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(String(localized: "watch.now_playing.title", defaultValue: "Now Playing"))
                    .font(.headline)
            }
        }
    }

    private var showsTrackedActivityControls: Bool {
        client.nowPlaying.isTrackedActivitySession &&
        (
            client.nowPlaying.isActiveSession ||
            client.nowPlaying.isPaused ||
            client.hasRecoverableNowPlayingSession ||
            client.isRecoveringRecentSession
        )
    }

    @ViewBuilder
    private var statusRow: some View {
        if showsTrackedActivityControls {
            VStack(spacing: 6) {
                Label(
                    client.trackedActivityStatusText,
                    systemImage: client.nowPlaying.isPaused ? "pause.circle.fill" : "figure.walk.motion"
                )
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Watch.NowPlaying.TrackedStatus")

                if let transportStatusText = client.transportStatusText {
                    Label(transportStatusText, systemImage: client.transportStatusSymbol)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let elapsedSeconds = client.nowPlaying.elapsedSeconds {
                    Text(format(seconds: elapsedSeconds))
                        .font(.title3.monospacedDigit())
                }
            }
        } else if let restSeconds = client.nowPlaying.restRemainingSeconds, client.nowPlaying.isRestRunning {
            Text(format(seconds: restSeconds))
                .font(.title2.monospacedDigit())
        } else {
            Text(String(localized: "watch.now_playing.status.no_active_session", defaultValue: "No active session"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var controlsRow: some View {
        if showsTrackedActivityControls {
            VStack(spacing: 8) {
                Button {
                    let kind: WatchCommandKind = client.nowPlaying.isPaused ? .resumeTrackedActivity : .pauseTrackedActivity
                    client.send(.init(kind: kind, sessionID: client.nowPlaying.sessionID))
                } label: {
                    Label(
                        presentation.trackedControlsPrimaryActionTitle(isPaused: client.nowPlaying.isPaused),
                        systemImage: client.nowPlaying.isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!client.canSendCommands)
                .accessibilityIdentifier("Watch.NowPlaying.PrimaryAction")

                Button {
                    client.send(.init(kind: .finishTrackedActivity, sessionID: client.nowPlaying.sessionID))
                } label: {
                    Label(
                        String(localized: "watch.now_playing.action.finish", defaultValue: "Finish"),
                        systemImage: "stop.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!client.canSendCommands || !client.nowPlaying.canFinish)
                .accessibilityIdentifier("Watch.NowPlaying.FinishAction")
            }
            .buttonStyle(.borderedProminent)
        } else {
            HStack(spacing: 12) {
                Button {
                    client.send(.init(kind: .previousSet))
                } label: {
                    Image(systemName: "backward.fill")
                }
                .disabled(!client.canSendCommands || !client.nowPlaying.canGoPrevious)

                Button {
                    client.send(.init(kind: .markSetComplete, sessionID: client.nowPlaying.sessionID, setID: client.nowPlaying.setID))
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .disabled(!client.canSendCommands || !client.nowPlaying.isActiveSession)

                Button {
                    client.send(.init(kind: .nextSet))
                } label: {
                    Image(systemName: "forward.fill")
                }
                .disabled(!client.canSendCommands || !client.nowPlaying.canGoNext)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var footerRow: some View {
        if showsTrackedActivityControls {
            Text(
                presentation.footerText(
                    isTrackedActivitySession: client.nowPlaying.isTrackedActivitySession,
                    isRecoveringRecentSession: client.isRecoveringRecentSession
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        } else {
            Button {
                client.send(.init(kind: .toggleRestTimer))
            } label: {
                HStack {
                    Image(systemName: client.nowPlaying.isRestRunning ? "pause.fill" : "play.fill")
                    if let secs = client.nowPlaying.restRemainingSeconds, client.nowPlaying.isActiveSession {
                        Text(format(seconds: secs))
                            .monospacedDigit()
                    } else {
                        Text(String(localized: "watch.now_playing.rest", defaultValue: "Rest"))
                    }
                }
            }
            .disabled(!client.canSendCommands || !client.nowPlaying.isActiveSession)
            .buttonStyle(.bordered)
        }
    }

    private func format(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
