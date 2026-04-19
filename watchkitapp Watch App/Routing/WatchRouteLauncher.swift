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
    private var preservesSeededShortcutsRoute = false

    func showShortcuts() {
        preservesSeededShortcutsRoute = false
        route = .shortcuts
    }

    func openNowPlaying() {
        preservesSeededShortcutsRoute = false
        suppressedSessionID = nil
        autoOpenArmed = false
        route = .nowPlaying
    }

    func armAutoOpenControls() {
        preservesSeededShortcutsRoute = false
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
            preservesSeededShortcutsRoute = false
            autoOpenArmed = false
            suppressedSessionID = nil
            if route == .nowPlaying {
                route = .shortcuts
            }
            return
        }

        guard !(preservesSeededShortcutsRoute && route == .shortcuts) else {
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
        preservesSeededShortcutsRoute = route == .shortcuts
        autoOpenArmed = false
        suppressedSessionID = nil
    }
}
