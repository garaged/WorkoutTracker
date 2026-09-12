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


## Quick-start timing extension (schema 6)

`TrackedActivitySession.quickStartTimingBlob` is optional in the local store. Typed backup schema 6 encodes its exact bytes as a base64 string, or null when absent. Version-5 backups without the field remain valid and restore with no quick-start payload. Schema 6 deliberately causes older applications that support only version 5 to reject the import rather than silently discard timer state.

The backup layer preserves unknown activity-kind raw IDs and opaque payload bytes, including unknown payload versions and damaged inner JSON. The quick-start runtime validates the inner payload before use; importing a backup is not permission to reset or reinterpret unreadable timing data. Invalid outer base64 or a non-string/non-null attribute is rejected during parsing, before any existing records are deleted. No additional model or alternate history store is introduced, so BackupManifest membership is unchanged.
