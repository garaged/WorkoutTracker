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
            .onAppear { client.start() }
            .onChange(of: client.nowPlaying.isActiveSession) { _, isActive in
                if !isActive, launcher.route == .nowPlaying {
                    launcher.showShortcuts()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
