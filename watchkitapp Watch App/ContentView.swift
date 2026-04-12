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
                        launcher.showShortcuts()
                    }
                }
            }
            .onAppear {
                client.start()
                if let seed = WatchUITestSeed.current {
                    launcher.applyUITestSeedRoute(seed.route == .nowPlaying ? .nowPlaying : .shortcuts)
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
        }
    }


    private func syncRouteWithNowPlaying() {
        let hasSession = client.hasRecoverableNowPlayingSession

        if hasSession {
            if launcher.route == .shortcuts {
                launcher.openNowPlaying()
            }
            launcher.consumeAutoOpenIfPossible(hasActiveSession: true)
        } else if launcher.route == .nowPlaying {
            launcher.showShortcuts()
        }
    }
}

#Preview {
    ContentView()
}
