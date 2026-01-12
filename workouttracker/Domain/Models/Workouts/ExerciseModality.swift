import Foundation

enum ExerciseModality: String, Codable, CaseIterable {
    /// Typical strength movement: reps + (optional) weight.
    case strength

    /// Timed holds / intervals: seconds (and optional weight).
    case timed

    /// Cardio-ish: time and/or distance. (You can expand later.)
    case cardio

    /// For things like stretching, mobility, rehab.
    case mobility
}
