import SwiftUI

struct ContentView: View {
    @StateObject private var client = WatchConnectivityClient.shared
    @StateObject private var launcher = WatchRouteLauncher()

    var body: some View {
        NavigationStack {
            Group {
                switch launcher.route {
                case .shortcuts:
                    WatchWorkoutShortcutsView(client: client, launcher: launcher)

                case .nowPlaying:
                    NowPlayingWorkoutControlsView {
                        launcher.userClosedNowPlaying(currentSessionID: client.nowPlaying.sessionID)
                    }
                }
            }
            .onAppear {
                client.start()

                if let seed = WatchUITestSeed.current {
                    switch seed.route {
                    case .nowPlaying:
                        launcher.applyUITestSeedRoute(.nowPlaying)
                    case .shortcuts:
                        launcher.applyUITestSeedRoute(.shortcuts)
                    }
                }

                syncRouteWithNowPlaying()
            }
            .onChange(of: client.hasRecoverableNowPlayingSession) { _, _ in
                syncRouteWithNowPlaying()
            }
            .onChange(of: client.nowPlaying.sessionID) { _, _ in
                syncRouteWithNowPlaying()
            }
            .onChange(of: client.lastStateReceivedAt) { _, _ in
                syncRouteWithNowPlaying()
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }

    private func syncRouteWithNowPlaying() {
        launcher.consumeAutoOpenIfPossible(
            hasActiveSession: client.hasRecoverableNowPlayingSession,
            sessionID: client.nowPlaying.sessionID
        )
    }

    private func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased() else { return }
        guard scheme == "workouttrackerwatch" else { return }

        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()

        if host == "now-playing" || path.contains("now-playing") || path.contains("current-activity") {
            launcher.openNowPlaying()
            client.start()
            client.requestState()
            return
        }

        if host == "shortcuts" || path.contains("shortcuts") || path.isEmpty || path == "/" {
            launcher.showShortcuts()
        }
    }
}

#Preview {
    ContentView()
}
