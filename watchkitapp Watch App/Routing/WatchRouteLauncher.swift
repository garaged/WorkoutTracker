import Foundation
import Combine

@MainActor
final class WatchRouteLauncher: ObservableObject {
    enum Route: Equatable {
        case shortcuts
        case nowPlaying
    }

    @Published private(set) var route: Route = .shortcuts
    private var shouldAutoOpenControls = false

    func showShortcuts() {
        route = .shortcuts
        shouldAutoOpenControls = false
    }

    func openNowPlaying() {
        route = .nowPlaying
        shouldAutoOpenControls = false
    }

    func armAutoOpenControls() {
        shouldAutoOpenControls = true
    }

    func consumeAutoOpenIfPossible(hasActiveSession: Bool) {
        guard shouldAutoOpenControls, hasActiveSession else { return }
        route = .nowPlaying
        shouldAutoOpenControls = false
    }
}
