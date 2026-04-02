// File: workouttracker/Services/Backup/BackupManifest.swift
import Foundation

/// One authoritative list of what counts as "user data" for export/restore.
///
/// Opinionated rules:
/// - Keep caches / derived data OUT of backups.
/// - Include the full workout graph, not just top-level models,
///   so restore can reconnect routines, planned sets, sessions, and logged sets.
enum BackupManifest {

    static func userDataTypes() -> [BackupService.AnyBackupType] {
        [
            // Workouts catalog / definitions
            .init(Exercise.self),
            .init(WorkoutRoutine.self),
            .init(WorkoutRoutineItem.self),
            .init(WorkoutSetPlan.self),

            // Performed workout graph
            .init(WorkoutSession.self),
            .init(WorkoutSessionExercise.self),
            .init(WorkoutSetLog.self),

            // Tracked activity graph
            .init(TrackedActivitySession.self),

            // Scheduling / day timeline
            .init(Activity.self),

            // Body tracking
            .init(BodyMeasurement.self),

            // Template system
            .init(TemplateActivity.self),
            .init(TemplateInstanceOverride.self)
        ]
    }
}
