# Workout Tracker

A lightweight, on-device workout logging app built with **SwiftUI + SwiftData**.

- ✅ On-device first (no account required)
- ✅ Fast logging + linked routines + history/compare
- ✅ Progress insights + Spanish localization in v2.0.0
- ✅ Apache 2.0 licensed

## Screenshots

[Screenshots](docs/screenshots/) and reference images here.

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

### v2.3.0 — Programs / progression / coaching

Workout Tracker 2.3.0 adds structured training programs with assignment, progress tracking, next-step planning, typed progression rules, and program pack import/export. You can now browse programs, schedule them into your calendar, follow weekly progress, and get clearer guidance on what to do next.

### v2.2.2 — Performance, responsiveness, and architecture hardening

This update makes tracked activities much more reliable on iPhone and Apple Watch. We fixed issues around finishing activities, opening the current activity from widgets and watch surfaces, and improved summary and Apple Health save flow.

- Fixed tracked-activity finish hang
- Restored tracked-activity routing across phone/watch/widget surfaces
- Fixed watch current-activity launch behavior
- Stabilized summary/export flow
- Known limitation: watch widget appearance may lag briefly after activity start


### v2.2.1 — Tracked activity polish and trust pass

- Apple Health auto-save for completed tracked activities
- Stronger interrupted/stale tracked-activity recovery
- Clearer route capture and route-attachment status
- Better tracked-activity history/progress presentation
- Improved watch recovery and current-activity controls
- Localization and reliability cleanup across new tracked-activity surfaces


### v2.2.0 — Tracked activities + Apple Health foundation

What’s new in 2.2.0:

- Added tracked activities: Walking, Running, Hiking, and Yoga
- New Activities area with activity-specific live tracking and summaries
- Save tracked activities to Apple Health
- Apple Watch controls for tracked activities
- Outdoor route capture foundation for eligible activities
- Better history, progress, recovery, and localization for tracked activities

### v2.1.1 — Stabilization of system integrations

`v2.1.1` focuses on making the system surfaces introduced in `v2.1.0` feel dependable in real use.

This release improves how WorkoutTracker behaves when widgets, Shortcuts, Live Activities, watch actions, and deep links try to open workout state that may have changed since those surfaces were created.

#### User-facing changes

* safer deep-link behavior when a target session or routine no longer exists
* more reliable resume/open behavior from Shortcuts and App Intents
* cleaner widget empty states and better stale-link recovery
* improved Live Activity cleanup after finishing or deleting a session
* more dependable watch-to-phone coordination for workout entry actions
* better handling of no-active-session and multiple-active-session edge cases

#### Technical changes

* centralized external-route resolution and fallback handling
* improved pending launch consumption so stale routes do not linger
* hardened widget snapshot/deep-link validation
* improved Live Activity reconciliation across relaunch and background scenarios
* aligned watch routing with the same session-selection policy used elsewhere
* expanded regression coverage for seeded external-entry flows and launch-time recovery

#### Regression and quality work

This release also includes a targeted stabilization pass for UI and integration regressions uncovered while hardening system integrations, including:

* finish-summary visibility reliability
* add/copy-set row visibility under session editing flows
* linked warm-up / main / cool-down flow coverage
* scheduled workout start resilience during immediate rotation
* started-workout deletion reminder cleanup
* stricter UITestHost launch validation and seed assertions

#### Notes

`v2.1.1` is a stabilization release.
It is focused on reliability, fallback behavior, and regression hardening rather than expanding feature scope.

### v2.1.0 — System Integrations

WorkoutTracker now connects much more cleanly with system surfaces across iPhone, widgets, Live Activities, Shortcuts, and Apple Watch. This release adds a shared routing and snapshot foundation so external entry points open the correct place, stay safer around workout state, and behave more consistently.

Highlights:
- Canonical deep-link and route handling
- Safer App Intents foundation
- Shortcuts for common workout actions
- Home Screen widgets for active session and streaks
- Live Activity for active workouts
- Apple Watch quick entry points and working watch controls

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

## Coming up

No big plans right now, want to [propose something](https://github.com/garaged/WorkoutTracker/issues) ? 

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
