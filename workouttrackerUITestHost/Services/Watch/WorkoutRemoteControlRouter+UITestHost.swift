import Foundation
import SwiftData

@MainActor
final class WorkoutRemoteControlRouter {

    static let shared = WorkoutRemoteControlRouter()
    private init() {}

    func start(modelContainer: ModelContainer) {
        // No-op in UI test host
    }

    func updateCursor(sessionID: UUID, exerciseID: UUID?, setID: UUID?) {
        // No-op in UI test host
    }

    func clearNowPlaying(sessionID: UUID) {
        // No-op in UI test host
    }

    func focusTrackedActivity(sessionID: UUID) {
        // No-op in UI test host
    }

    func clearTrackedActivityFocus(sessionID: UUID) {
        // No-op in UI test host
    }

    func refreshNowPlaying() {
        // No-op in UI test host
    }
}
