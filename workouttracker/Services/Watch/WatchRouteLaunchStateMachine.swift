import Foundation

struct WatchRouteLaunchStateMachine {
    enum Route: Equatable {
        case shortcuts
        case nowPlaying
    }

    private(set) var route: Route = .shortcuts
    private(set) var shouldAutoOpenControls = false

    mutating func showShortcuts() {
        route = .shortcuts
        shouldAutoOpenControls = false
    }

    mutating func openNowPlaying() {
        route = .nowPlaying
        shouldAutoOpenControls = false
    }

    mutating func armAutoOpenControls() {
        shouldAutoOpenControls = true
    }

    mutating func consumeAutoOpenIfPossible(hasActiveSession: Bool) {
        guard shouldAutoOpenControls, hasActiveSession else { return }
        route = .nowPlaying
        shouldAutoOpenControls = false
    }
}
