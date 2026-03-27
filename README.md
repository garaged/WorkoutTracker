# Workout Tracker

A lightweight, on-device workout logging app built with **SwiftUI + SwiftData**.

- ✅ On-device first (no account required)
- ✅ Fast logging + linked routines + history/compare
- ✅ Progress insights + Spanish localization in v2.0.0
- ✅ Apache 2.0 licensed

## Screenshots

> TODO: Add screenshots later (recommended).  
> Path: `docs/screenshots/` and reference images here.

## Feature overview

Workout Tracker is a lightweight, on-device workout logging app built with SwiftUI + SwiftData.

Core features:
- **Routines & templates**: create routines, then optionally attach linked warm-up and cool-down routines
- **Fast workout logging**: track sets (weight/reps), mark sets complete, and keep momentum during training
- **Smarter rest timing**: keep the timer visible through ready/overdue states and add extra rest quickly
- **Progress Hub**: review strength, volume, consistency, and recovery trends with honest low-data handling
- **History that’s useful**: browse past sessions, compare two sessions, and review per-exercise performance
- **Personal records (PRs)**: track best sets and highlight progress
- **Preferences & localization**: unit settings plus Spanish localization for the key v2 flows
- **Backup / export**: export your data for safe keeping (and import if supported in your build)

Non-goals:
- No social feed, no accounts required, no “gamification” bloat (yet?)

## Changelog

### 2.0.3

- Added the first wave of built-in exercise localization
- Improved localized exercise search and naming consistency across the app
- Added exercise thumbnails in the picker when illustrations are available
- Improved program import/export compatibility for localized built-in exercises
- Fixed and hardened several data, browsing, and UI reliability paths

### 2.0.2 

This release improves accessibility, readability, and layout resilience across key parts of WorkoutTracker.

#### Accessibility and readability

- improved accessibility labels and spoken summaries across sessions, Home, Progress, and summary flows
- clearer communication for current, completed, overdue, paused, and low-data states
- better support for larger text sizes on dense screens

#### Session and Home resilience

- improved workout set row layout across different phone sizes
- made session controls and active-session cards more resilient on compact and large phones
- improved visibility and behavior for current-set and active-rest states
- reduced cramped layouts and improved wrapping in key session and Home flows

#### Progress and summary resilience

- added accessible text summaries for progress trends and chart-based insights
- improved exercise progress detail readability without relying only on charts
- made progress cards, finish summary, and reflection layouts adapt better to larger text
- improved low-data states so they remain clear and informative

### v2.0.1

- Improved session resume reliability from Home and Calendar.
- Added clearer stale-session recovery options: Resume, Finish now, Discard, and Keep for later.
- Polished the finish summary with clearer completed/skipped set counts, elapsed time, PR highlights, and segment-aware details.
- Refined export and backup wording, naming, and empty states.
- Standardized copy across key session flows and improved localization consistency.

### v2.0.0

- New Progress Hub with strength, volume, consistency, and recovery insights
- Smarter rest timer behavior with overdue visibility and quick extra-rest actions
- Linked warm-up and cool-down routines
- Spanish localization across the core v2 flows
- Accessibility, copy, and release-candidate hardening
- Calories intentionally deferred to v2.0.1

### v1.0.8

- Fixed a UI-test launch regression where Home Resume no longer opened the active workout session
- Restored test routing to use the same root session-presentation path as the production Home flow

### v1.0.7

Misc. fixes (no more warnings). Rest time counter improvements for full robustness.

### v1.0.6

Routine editing, improving watch sync.

### v1.0.5 Basic exercise image sets, backup/restore including activities

Implement unit selection in Settings.

Sound for rest time: Makes it easy to follow up without keeping an eye on the phone.

Exercise illustration sets:

- workouttracker/Support/ExerciseIllustrationSet.swift
  - Added `maleV1` and user-facing labels for all three bundled illustration families.
- workouttracker/Support/ExerciseIllustrationCatalog.swift
  - Extended the central asset resolver so every stable exercise key can resolve to dummy, female, or male assets.
- workouttracker/Services/Settings/UserPreferences.swift
  - Added a persisted `exerciseIllustrationSet` preference and kept `dummyV1` as the default / reset value.
- workouttracker/Features/Settings/ExerciseIllustrationSetPickerSection.swift
  - Updated the Settings UI to bind to `UserPreferences` and expose all three illustration options.

Backup/restore supporting activities.

### DONE v1.0.4 - Watch support, UI improvements

- Basic Apple Watch support
- Small UI/Usability improvements

### DONE in v1.0.1 (2) - Better communication with users

- Add a super easy “Feedback / Report a bug” button that actually gives useful info.
- Make support routes obvious (Support link + a privacy-friendly way to reach out).

### DONE in v1.0.1 (1) - Session reflections (comments + mood)

- At the end of a session, pop a quick “How did it feel?” step:
  - pick a mood/result in 1–2 taps
  - optionally jot a short note
- Idea is to capture the vibe/context without slowing down logging.

### DONE in v1.0.1 (1) - iPad support

- Make the UI feel right on big screens (Split View, better spacing/density, keyboard-friendly).
- Goal: more of a “coach clipboard” vibe for gym/home.

### DONE in v1.0.1 (1) - Programs / plans (shareable)

- Add real training programs people can download/import.
- Later: let the community submit programs too (but that needs moderation + somewhere to host them).


## Coming up

### Fix issues and implement feedback improvements

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

## Support

Best way to get help or report issues:

- **Report a bug / request a feature:** open a GitHub issue  
  https://github.com/garaged/WorkoutTracker/issues/new/choose
- **Browse existing issues:**  
  https://github.com/garaged/WorkoutTracker/issues
- **Email support:** garaged@gmail.com

When reporting a bug, include:
- steps to reproduce
- what you expected vs what happened
- your iOS version + app version (the in-app Support screen can copy a summary)

## FAQ

**Does Workout Tracker require an account?**  
No. The app is on-device first.

**Is any workout data uploaded anywhere?**  
By default, no. Your data stays on-device unless you choose to export/share it.

**How do I export/backup my data?**  
Use the in-app backup/export feature (see Settings).

**How do I report a bug?**  
Settings → Support → “Open GitHub Issue” (preferred) or “Email Support”.

**Do you use analytics / trackers / ad SDKs?**  
No (see `PRIVACY.md`).

## Privacy

Short version: your workout data stays **on-device** by default.

See the full statement in [`PRIVACY.md`](./PRIVACY.md).

## Build

- Xcode 16+ (or the version you target)
- iOS target: (set this to your project minimum)

Open `workouttracker.xcodeproj` (or `.xcworkspace`) and run the `workouttracker` scheme.

## License

Licensed under the Apache License 2.0. See `LICENSE` and `NOTICE`.

## Sponsor

If you like the project and want to support maintenance and new features you can do it at https://github.com/sponsors/garaged
