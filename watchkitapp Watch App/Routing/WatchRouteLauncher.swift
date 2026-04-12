import Foundation
import Combine

@MainActor
final class WatchRouteLauncher: ObservableObject {
    enum Route {
        case shortcuts
        case nowPlaying
    }

    @Published private(set) var route: Route = .shortcuts

    private var autoOpenArmed = false
    private var suppressedSessionID: String?

    func showShortcuts() {
        route = .shortcuts
    }

    func openNowPlaying() {
        suppressedSessionID = nil
        autoOpenArmed = false
        route = .nowPlaying
    }

    func armAutoOpenControls() {
        autoOpenArmed = true
        suppressedSessionID = nil
    }

    func userClosedNowPlaying(currentSessionID: String?) {
        if let currentSessionID, !currentSessionID.isEmpty {
            suppressedSessionID = currentSessionID
        } else {
            suppressedSessionID = nil
        }
        autoOpenArmed = false
        route = .shortcuts
    }

    func consumeAutoOpenIfPossible(hasActiveSession: Bool) {
        consumeAutoOpenIfPossible(hasActiveSession: hasActiveSession, sessionID: nil)
    }

    func consumeAutoOpenIfPossible(hasActiveSession: Bool, sessionID: String?) {
        guard hasActiveSession else {
            autoOpenArmed = false
            suppressedSessionID = nil
            if route == .nowPlaying {
                route = .shortcuts
            }
            return
        }

        guard let sessionID, !sessionID.isEmpty else {
            if autoOpenArmed || route == .shortcuts {
                route = .nowPlaying
            }
            autoOpenArmed = false
            return
        }

        if let suppressedSessionID, suppressedSessionID != sessionID {
            self.suppressedSessionID = nil
        }

        guard suppressedSessionID != sessionID else {
            autoOpenArmed = false
            return
        }

        if autoOpenArmed || route == .shortcuts {
            route = .nowPlaying
        }

        autoOpenArmed = false
    }

    func applyUITestSeedRoute(_ route: Route) {
        self.route = route
        autoOpenArmed = false
        suppressedSessionID = nil
    }
}
