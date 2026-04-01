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

            restRow
        }
        .padding(.vertical, 8)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onClose)
            }
        }
        .onAppear { client.start() }
    }

    private var header: some View {
        VStack(spacing: 4) {
            if client.nowPlaying.isActiveSession {
                Text(client.nowPlaying.exerciseName ?? "Workout")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

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
                Text("No active workout")
                    .font(.headline)
                Text("Start on iPhone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !client.canSendCommands {
                Text("Phone unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !client.isReachable {
                Text("Phone app closed — commands may take a moment")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsRow: some View {
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

    private var restRow: some View {
        Button {
            client.send(.init(kind: .toggleRestTimer))
        } label: {
            HStack {
                Image(systemName: client.nowPlaying.isRestRunning ? "pause.fill" : "play.fill")
                if let secs = client.nowPlaying.restRemainingSeconds, client.nowPlaying.isActiveSession {
                    Text(format(seconds: secs))
                        .monospacedDigit()
                } else {
                    Text("Rest")
                }
            }
        }
        .disabled(!client.canSendCommands || !client.nowPlaying.isActiveSession)
        .buttonStyle(.bordered)
    }

    private func format(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
