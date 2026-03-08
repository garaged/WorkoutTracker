import Foundation

/// Centralizes how the session screen decides whether a set should render with the
/// timed/cardio editor or the strength editor.
///
/// Why this exists:
/// - `WorkoutSessionExercise.trackingStyle` is the semantic source of truth.
/// - timed fields on `WorkoutSetLog` are still useful as a fallback for older data or
///   partially migrated sessions.
/// - keeping this logic in one pure helper makes it easy to regression-test.
enum WorkoutSetRowRouting {

    static func shouldUseTimedRow(
        trackingStyle: ExerciseTrackingStyle,
        hasTargetDuration: Bool,
        hasActualDuration: Bool,
        hasTargetDistance: Bool,
        hasActualDistance: Bool
    ) -> Bool {
        trackingStyle.showsDuration ||
        trackingStyle.showsDistance ||
        hasTargetDuration ||
        hasActualDuration ||
        hasTargetDistance ||
        hasActualDistance
    }

    static func shouldUseTimedRow(for exercise: WorkoutSessionExercise, set: WorkoutSetLog) -> Bool {
        shouldUseTimedRow(
            trackingStyle: exercise.trackingStyle,
            hasTargetDuration: set.targetDurationSeconds != nil,
            hasActualDuration: set.actualDurationSeconds != nil,
            hasTargetDistance: set.targetDistance != nil,
            hasActualDistance: set.actualDistance != nil
        )
    }
}
