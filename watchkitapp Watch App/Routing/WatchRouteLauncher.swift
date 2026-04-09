import Foundation
import Combine

@MainActor
final class WatchRouteLauncher: ObservableObject {
    typealias Route = WatchRouteLaunchStateMachine.Route

    @Published private(set) var route: Route = .shortcuts
    private var stateMachine = WatchRouteLaunchStateMachine()

    func showShortcuts() {
        stateMachine.showShortcuts()
        route = stateMachine.route
    }

    func openNowPlaying() {
        stateMachine.openNowPlaying()
        route = stateMachine.route
    }

    func armAutoOpenControls() {
        stateMachine.armAutoOpenControls()
    }

    func consumeAutoOpenIfPossible(hasActiveSession: Bool) {
        stateMachine.consumeAutoOpenIfPossible(hasActiveSession: hasActiveSession)
        route = stateMachine.route
    }

    func applyUITestSeedRoute(_ route: Route) {
        self.route = route
    }
}
