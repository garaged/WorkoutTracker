import Foundation

enum ExerciseTrackingStyle: String, CaseIterable, Codable, Hashable, Identifiable {
    case strength        // reps + weight + rpe + rest
    case repsOnly        // reps (+ optional rpe/rest)
    case timeOnly        // duration (+ optional rest)
    case timeDistance    // duration + distance (cardio)
    case distanceOnly    // distance only
    case notesOnly       // no numeric fields

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Strength (Reps + Weight)"
        case .repsOnly: return "Reps only"
        case .timeOnly: return "Timed (Duration)"
        case .timeDistance: return "Cardio (Duration + Distance)"
        case .distanceOnly: return "Distance only"
        case .notesOnly: return "Notes only"
        }
    }

    var showsReps: Bool { self == .strength || self == .repsOnly }
    var showsWeight: Bool { self == .strength }
    var showsRPE: Bool { self == .strength || self == .repsOnly }
    var showsRest: Bool { self != .notesOnly }
    var showsDuration: Bool { self == .timeOnly || self == .timeDistance }
    var showsDistance: Bool { self == .timeDistance || self == .distanceOnly }

    /// Default number of planned “rows” when adding an exercise to a routine.
    var defaultPlannedRows: Int {
        switch self {
        case .strength, .repsOnly: return 3
        case .timeOnly, .timeDistance, .distanceOnly: return 1
        case .notesOnly: return 0
        }
    }
}
