import SwiftUI

struct NowPlayingWorkoutControlsView: View {

    let onClose: () -> Void
    @StateObject private var client = WatchConnectivityClient.shared

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            controlsRow
            footerRow
        }
        .padding(.vertical, 8)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "watch.now_playing.action.back", defaultValue: "Back"), action: onClose)
            }
        }
        .onAppear { client.start() }
    }

    private var header: some View {
        VStack(spacing: 4) {
            if client.nowPlaying.isActiveSession {
                Text(client.nowPlaying.exerciseName ?? String(localized: "watch.now_playing.fallback.workout", defaultValue: "Workout"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if client.nowPlaying.isTrackedActivitySession,
                   let elapsedSeconds = client.nowPlaying.elapsedSeconds {
                    Text(format(seconds: elapsedSeconds))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                if let title = client.nowPlaying.setTitle {
                    Text(title)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                if let detail = client.nowPlaying.setDetail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            } else {
                Text(String(localized: "watch.now_playing.empty.title", defaultValue: "No active workout"))
                    .font(.headline)
                Text(String(localized: "watch.now_playing.empty.subtitle", defaultValue: "Start on iPhone or watch"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !client.canSendCommands {
                Text(String(localized: "watch.now_playing.status.phone_unavailable", defaultValue: "Phone unavailable"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !client.isReachable {
                Text(
                    String(
                        localized: "watch.now_playing.status.phone_closed",
                        defaultValue: "Phone app closed — commands may take a moment"
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var controlsRow: some View {
        if client.nowPlaying.isTrackedActivitySession {
            HStack(spacing: 12) {
                Button {
                    client.send(
                        .init(
                            kind: client.nowPlaying.isPaused ? .resumeTrackedActivity : .pauseTrackedActivity,
                            sessionID: client.nowPlaying.sessionID
                        )
                    )
                } label: {
                    Image(systemName: client.nowPlaying.isPaused ? "play.fill" : "pause.fill")
                }
                .disabled(!client.canSendCommands || !client.nowPlaying.canPauseOrResume)

                Button {
                    client.send(.init(kind: .finishTrackedActivity, sessionID: client.nowPlaying.sessionID))
                } label: {
                    Image(systemName: "stop.fill")
                }
                .disabled(!client.canSendCommands || !client.nowPlaying.canFinish)
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
        if client.nowPlaying.isTrackedActivitySession {
            HStack(spacing: 8) {
                Image(systemName: client.nowPlaying.isPaused ? "pause.circle.fill" : "figure.walk.motion")
                Text(
                    client.nowPlaying.isPaused
                        ? String(localized: "watch.now_playing.state.paused", defaultValue: "Paused")
                        : String(localized: "watch.now_playing.state.tracking_live_on_phone", defaultValue: "Tracking live on iPhone")
                )
                .font(.footnote)
                .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
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
