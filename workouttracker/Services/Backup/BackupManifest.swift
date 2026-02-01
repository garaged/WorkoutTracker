// workouttracker/Services/Backup/BackupManifest.swift
import Foundation

/// One authoritative list of what counts as "user data" for export.
/// Opinionated: keep caches / derived data OUT of backups.
enum BackupManifest {

    static func userDataTypes() -> [BackupService.AnyBackupType] {
        [
            // Workouts
            .init(Exercise.self),
            .init(WorkoutRoutine.self),
            .init(WorkoutSession.self),

            // Scheduling / day timeline
            .init(Activity.self),

            // Body tracking
            .init(BodyMeasurement.self),

            // Template system (if you want templates backed up too)
            .init(TemplateActivity.self),
            .init(TemplateInstanceOverride.self)
        ]
    }
}
