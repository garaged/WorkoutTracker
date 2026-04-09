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
            }
            .onChange(of: client.hasRecoverableNowPlayingSession) { _, hasSession in
                if !hasSession, launcher.route == .nowPlaying {
                    launcher.showShortcuts()
                }
            }
            .onChange(of: client.hasRecoverableNowPlayingSession) { _, hasSession in
                launcher.consumeAutoOpenIfPossible(hasActiveSession: hasSession)
            }
        }
    }
}

#Preview {
    ContentView()
}
