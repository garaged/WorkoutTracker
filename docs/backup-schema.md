# Backup schema note

## Typed workout backup contract

Workout backup/restore now uses a **typed export contract** for the workout graph.

This is intentional.

The workout backup path must preserve:

* stable domain IDs (`UUID` values from the models)
* required fields such as routine and exercise names
* relationship references across the full graph
* nested ordering fields used by routines, session exercises, and set logs

The current workout graph covered by backup includes:

* `Exercise`
* `WorkoutRoutine`
* `WorkoutRoutineItem`
* `WorkoutSetPlan`
* `WorkoutSession`
* `WorkoutSessionExercise`
* `WorkoutSetLog`

## Why typed export exists

A previous implementation relied too heavily on generic reflection for SwiftData models.
That caused backup regressions such as:

* internal SwiftData `PersistentIdentifier(...)` values leaking into backup IDs
* required fields missing from exported entities
* relationship refs not reliably matching restored entity IDs

For workout data, backups are now treated as a **data contract**, not a debug dump.

## Refactor guardrail

When changing workout models or backup code:

* do **not** replace typed workout export with generic reflection-only export
* preserve domain UUIDs as the backup identity
* preserve explicit export of required fields and relationship refs
* update backup tests when the workout graph changes

If a new workout-related model is added to the persisted workout graph, update:

* `BackupManifest`
* `BackupService` typed export/restore mapping
* the backup round-trip regression test

## Compatibility note for older backups

Some backups created before the typed workout export fix may be malformed.

Known issues in older backup files may include:
- internal SwiftData `PersistentIdentifier(...)` values stored instead of domain UUIDs
- missing required workout fields such as routine or exercise names
- relationship references that do not reconnect cleanly on restore

Because of that, **pre-fix backups are not guaranteed to restore fully**.

Current and future backups should be created from versions that use the typed workout backup contract documented in this file.

If a user reports restore failures from an older backup, treat the backup file as potentially malformed before assuming the current restore path is broken.

## Testing expectation

The backup round-trip regression test exists to verify that a seeded workout graph can:

1. export to JSON
2. restore into a clean store
3. preserve IDs, required fields, relationships, and ordering metadata

If that test fails after a refactor, treat it as a backup contract regression unless proven otherwise.

