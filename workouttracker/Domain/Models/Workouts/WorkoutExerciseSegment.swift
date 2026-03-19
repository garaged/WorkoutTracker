import Foundation

enum WorkoutExerciseSegment: String, Codable, CaseIterable, Hashable {
    case warmUp = "warmUp"
    case main = "main"
    case coolDown = "coolDown"

    var displayName: String {
        switch self {
        case .warmUp: return "Warm-up"
        case .main: return "Main"
        case .coolDown: return "Cool-down"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .warmUp: return "WU"
        case .main: return "Main"
        case .coolDown: return "CD"
        }
    }
}
