import Foundation

extension WorkoutRoutineItem {
    var trackingStyle: ExerciseTrackingStyle {
        get { ExerciseTrackingStyle(rawValue: trackingStyleRaw) ?? .strength }
        set { trackingStyleRaw = newValue.rawValue }
    }
}
