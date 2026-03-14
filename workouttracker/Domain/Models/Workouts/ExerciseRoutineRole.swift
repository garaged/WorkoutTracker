import Foundation

enum ExerciseRoutineRole: String, Codable, CaseIterable, Hashable, Identifiable {
    case warmUp
    case coolDown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmUp: return "Warm-up"
        case .coolDown: return "Cool-down"
        }
    }
}
