# Workout Tracker

A lightweight, on-device workout logging app built with **SwiftUI + SwiftData**.

- ✅ On-device first (no account required)
- ✅ Fast logging + routines + history/compare
- ✅ Apache 2.0 licensed

## Screenshots

> TODO: Add screenshots later (recommended).  
> Path: `docs/screenshots/` and reference images here.

## Feature overview

Workout Tracker is a lightweight, on-device workout logging app built with SwiftUI + SwiftData.

Core features:
- **Routines & templates**: create routines and reuse them quickly
- **Fast workout logging**: track sets (weight/reps), mark sets complete, keep momentum
- **History that’s useful**: browse past sessions, compare two sessions, and review per-exercise performance
- **Personal records (PRs)**: track best sets and highlight progress
- **Preferences**: unit settings (kg/lb) and other quality-of-life settings
- **Backup / export**: export your data for safe keeping (and import if supported in your build)

Non-goals:
- No social feed, no accounts required, no “gamification” bloat (yet?)

## Architecture (SwiftData model)

The app follows a pragmatic “feature-first UI + shared domain models” structure:
- **SwiftUI** screens live under `workouttracker/Features/*`
- **Domain models** live under `workouttracker/Domain/Models/*`
- **Persistence** is handled via **SwiftData** (`ModelContainer`, `ModelContext`), keeping most data on-device.

At a high level, the data model revolves around:
- **Exercise**: your exercise library (name, muscle group, modality, etc.)
- **WorkoutRoutine**: a saved routine template
- **WorkoutSession**: a performed workout on a date/time
- **WorkoutSessionExercise**: an exercise instance inside a session
- **WorkoutSetLog**: an individual set (reps/weight/completed)

Typical relationship flow:
`WorkoutRoutine` → start workout → `WorkoutSession` → `WorkoutSessionExercise` → `WorkoutSetLog`

If you’re new to SwiftData:
- A `ModelContainer` owns the persistent store.
- Views and services use a `ModelContext` to fetch and mutate models.
- Keep write operations centralized (services/helpers) so UI stays simple.

> Tip: When you add/rename fields in SwiftData models, treat migrations intentionally.
> Prefer additive changes, and keep “data integrity helpers” close to the model layer.

## Contributing + code style

Contributions are welcome.

How to contribute:
1. Fork the repo and create a branch: `feature/<short-name>` or `fix/<short-name>`
2. Keep PRs focused (one theme per PR)
3. Include screenshots for UI changes
4. Add/adjust tests when behavior changes (unit tests and/or UI smoke tests)

Code style (project conventions):
- Prefer small SwiftUI views and extract subviews when a screen grows
- Avoid pushing business logic into Views; use small services/helpers
- Use clear naming over clever abstractions
- Keep SwiftData fetches predictable (sort orders and explicit predicates)

Quality gates:
- `⌘U` should pass (unit + UI tests if configured)
- No new warnings introduced

## Privacy

Short version: your workout data stays **on-device** by default.

See the full statement in [`PRIVACY.md`](./PRIVACY.md).

## Build

- Xcode 16+ (or the version you target)
- iOS target: (set this to your project minimum)

Open `workouttracker.xcodeproj` (or `.xcworkspace`) and run the `workouttracker` scheme.

## License

Licensed under the Apache License 2.0. See `LICENSE` (or `LICENCE.txt`) and `NOTICE`.
