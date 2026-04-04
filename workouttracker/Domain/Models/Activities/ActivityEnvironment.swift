import Foundation

/// Physical environment for a tracked activity.
enum ActivityEnvironment: String, Codable, CaseIterable, Sendable {
    case indoor
    case outdoor
    case unspecified
}
