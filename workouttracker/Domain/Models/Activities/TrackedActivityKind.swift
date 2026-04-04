import Foundation

/// First-class tracked activity kinds supported by the broader activity-tracking domain.
enum TrackedActivityKind: String, Codable, CaseIterable, Sendable {
    case walking
    case running
    case hiking
    case yoga

    var supportsDistance: Bool {
        switch self {
        case .walking, .running, .hiking:
            return true
        case .yoga:
            return false
        }
    }

    var supportsSteps: Bool {
        switch self {
        case .walking, .running, .hiking:
            return true
        case .yoga:
            return false
        }
    }

    var supportsPace: Bool {
        switch self {
        case .running:
            return true
        case .walking, .hiking, .yoga:
            return false
        }
    }

    var defaultEnvironment: ActivityEnvironment {
        switch self {
        case .walking, .running, .hiking:
            return .outdoor
        case .yoga:
            return .indoor
        }
    }
}
