import Foundation

/// User-selectable exercise illustration family.
///
/// Keep stored exercise keys stable (for example: "back_squat").
/// Resolve the actual asset name at render time from the selected set.
public enum ExerciseIllustrationSet: String, CaseIterable, Codable, Identifiable {
    case dummyV1 = "dummy_v1"
    case femaleV1 = "female_v1"
    case maleV1 = "male_v1"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dummyV1: return "Default (Neutral)"
        case .femaleV1: return "Female"
        case .maleV1: return "Male"
        }
    }
}
