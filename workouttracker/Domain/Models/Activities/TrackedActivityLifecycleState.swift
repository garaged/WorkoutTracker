import Foundation

/// Lifecycle for tracked activities.
enum TrackedActivityLifecycleState: String, Codable, CaseIterable, Sendable {
    case planned
    case inProgress
    case paused
    case completed
    case discarded

    var isTerminal: Bool {
        switch self {
        case .completed, .discarded:
            return true
        case .planned, .inProgress, .paused:
            return false
        }
    }
}
