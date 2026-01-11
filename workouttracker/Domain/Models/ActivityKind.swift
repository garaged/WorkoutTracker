import Foundation

/// High-level category for a scheduled Activity / TemplateActivity.
/// Keeping it simple now prevents your scheduler from becoming workout-specific.
enum ActivityKind: String, Codable, CaseIterable {
    case generic
    case workout
}
