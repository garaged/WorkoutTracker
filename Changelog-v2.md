# Version 2.3.0 - Programs, planning, progression, and pack import/export

WorkoutTracker 2.3.0 moves beyond one-off workout logging into structured training guidance. This release adds multi-week programs, honest progress tracking, typed progression rules, import/export for program packs, and a new Home planning surface that helps the user understand what to do next without hiding missed work.

## New

- Added first-class training programs with reusable templates, week/day structure, prescriptions, and stable identities
- Added program assignment and runtime execution state so template data stays separate from user progress
- Added a deterministic program planner that computes current week/day, next actionable training day, and week completion
- Added adherence tracking for completed days, missed days, repeat-week state, and deload cues
- Added typed progression rules for load increases, holds, repeat-week behavior, scheduled deloads, and double progression
- Added bundled Programs catalog support with a seeded V2 pack for core app flows and regression coverage
- Added program pack import/export with schema-versioned JSON, validation, and explicit conflict handling
- Added program asset installation/mapping so imported packs can resolve routines and exercises safely into the local library
- Added a Programs library with Installed and Catalog browsing
- Added program detail, assignment, and progress screens
- Added a Home planning hub that surfaces the active program, current week progress, and next recommended action
- Added program scheduling into the calendar/day timeline so a program can create planned workout activities from its structure

## Improved

- Program guidance is deterministic and explainable instead of relying on vague coaching copy
- Missed required sessions remain visible and honest instead of being silently treated as complete
- Program progress now stays connected to real routines, exercises, and scheduled workouts through stable pack asset mapping
- Imported and bundled program packs are safer to round-trip because validation now checks structure, references, and unsupported rule configuration explicitly
- Home now provides a calmer planning-oriented entry point into assigned program work

## Fixes and reliability

- Fixed multiple program-library and pack-linkage edge cases so bundled/imported programs install with the routines and exercises required for scheduling and session start flows
- Fixed program scheduling coverage so seeded program flows create real planned workout activities that can be opened and started from the timeline
- Improved seeded UITestHost program assertions so Programs smoke suites fail fast when catalog, assignment, or asset linkage data is missing
- Hardened Programs UI smoke coverage for library, assignment, adherence, progression, and seeded schedule/start flows
- Fixed the `ProgramsV2SmokeUITests` launch configuration so the seeded installed-program library is populated consistently, including the `es-MX` localized smoke path

# Version 2.2.2 - Performance, responsiveness, and architecture hardening

v2.2.2 is a stability-focused release for tracked activities across iPhone, widgets, and Apple Watch. It improves current-activity routing, watch/widget handoff, finish-summary reliability, and Health save/export flow, with multiple fixes to system-surface behavior and recovery after activity transitions.

- Tracked activity finish from phone works
- Summary opens without hanging
- Deferred autosave/manual export flow works
- Watch widget opens correctly
- Open on iPhone works
- Phone/watch current-activity routing is working again


# Version 2.2.1 - Tracked activity polish and trust pass

- Tracked activities auto-save to Health when enabled
- Failed Health exports are recoverable
- Partial-success Health exports are messaged honestly
- Exported vs local-edited state is honest
- Interrupted tracked activities recover clearly after relaunch/backgrounding
- Stale tracked activity prompts are understandable
- Route capture status and route attachment outcome are visible and non-misleading
- Denied/revoked location permission is handled cleanly
- Live timer and current metrics do not reset or stall during normal re-entry
- Delete semantics are honest for completed tracked activities
- Tracked activities feel visually first-class in history/progress
- Watch paused/recovering/current-activity states are clearer and resilient
- Backup/restore preserves new tracked-activity Health/recovery metadata
- All touched strings are localized and polished

# Version 2.2.0 - Tracked activities + HealthKit foundation

WorkoutTracker now supports tracked activities alongside strength workouts, with a new foundation for Apple Health, Apple Watch control, and outdoor route capture.

## New

Added tracked activities:
  - Walking
  - Running
  - Hiking
  - Yoga
- Added a dedicated Activities area to start and manage tracked activities
- Added activity-specific live screens and finish summaries
- Added Apple Health integration for saving completed tracked activities
- Added Apple Watch support for starting, pausing, resuming, and finishing tracked activities
- Added outdoor route capture foundation for eligible activities
- Added tracked activities to history and progress surfaces
- Added localization coverage for new tracked-activity and Health-related UI

Improved:
- Tracked activities now feel like a first-class part of the app instead of an add-on
- Finish summaries are more honest about low-data sessions and export state
- Health permission and export states are clearer in Settings and activity flows
- Recovery behavior for interrupted tracked activities is improved
- History and progress now present activity-appropriate metrics
- Watch mirroring for tracked activities is faster and more reliable

Notes:
- Apple Health saving is currently a user-controlled action from the finish summary
- Outdoor route capture is currently designed for foreground use
- Strength sessions and tracked activities remain separate by design, which keeps both flows cleaner and more trustworthy

# Version 2.1.1 - System integrations

## Hotfix for scroll to next set edge case

After much looking it was found that the scrolling to next set (when needed) was not working for sets that were not in the viewable space (like when a routine is long), this was fixed with a proper new UI test to prevent regression on this. It's been a long hard ride to keep this scrolling feature stable! 

## v2.1.1 — Stabilization of system integrations

This release focuses on making the system-integration surfaces introduced in v2.1.0 feel dependable.

### Highlights

* safer deep-link resolution and fallback behavior
* more robust Shortcuts / App Intents handling
* improved widget empty states and stale-link recovery
* better Live Activity reconciliation and cleanup
* cleaner watch-to-phone coordination
* stronger regression coverage for external-entry flows

### Notes

v2.1.1 is a stabilization release. It is focused on reliability, fallback behavior, and edge-case handling rather than new feature scope.


# Version 2.1.0 - System integrations

What’s New:
WorkoutTracker 2.1.0 brings major system integration improvements across iPhone, widgets, Live Activities, Shortcuts, and Apple Watch.

New in this release:
- Added smarter deep-link routing so external entry points open the correct workout, routine, or day
- Added Shortcuts support for:
  - Start Routine
  - Resume Workout
  - Go to Current Session
  - Start Rest Timer
  - Finish Current Session
- Added Home Screen widgets:
  - Active Session
  - Streak
- Added Live Activity support for active workouts, including current exercise, set progress, elapsed time, and rest state
- Added Apple Watch quick entry points and improved watch workout controls

## Improved

- More consistent resume/open behavior across system surfaces
- Safer action handling for resume, finish, and rest actions
- Better synchronization between phone, widgets, Live Activity, and watch
- Stronger routing and snapshot foundations for future integrations

## Notes
Next planned workout widget was intentionally deferred until planning data is reliable enough to surface honestly

# Version 2.0.3 — Exercise localization foundation + picker recognition

This release makes built-in exercises more language-aware and more visually recognizable, while keeping older data and custom exercises safe.

## Added

Stable built-in exercise identity using internal catalog keys
Initial localized built-in exercise names
Localized built-in exercise search in exercise browse surfaces
Shared exercise localization service for consistent built-in naming across the app
Picker thumbnails for exercises with available illustrations
Shared image-resolution service for exercise thumbnails

## Improved

Exercise picker now shows localized built-in names and supports localized search
Exercise library now shows localized built-in names for catalog exercises
Routine editor and routine detail views now use localized built-in names
Session screens now prefer the current localized built-in name when the exercise can still be resolved
History and progress surfaces now show more consistent built-in exercise naming
Program pack import/export now preserves stable built-in exercise identity across locales
Built-in exercise matching is safer during seed, starter-pack, and routine reconciliation
Kept intentionally stable
Custom exercise names are not auto-translated
Session snapshots and analytics calculations were not changed
Illustration-set choices in Settings remain the same
No new image overlay or preview modal was added in this version

## Reliability

Better compatibility with older stores and legacy packs
Cleaner fallback behavior when localized names or illustrations are missing
Test hardening across localized, routine, session, history, and picker flows

# Changelog v2.0.2

This update improves accessibility, layout resilience, and readability across key parts of the app.

## Accessibility and readability

- improved spoken labels and accessibility semantics across session, home, progress, and summary flows
- clearer state communication for current, completed, overdue, and paused states
- better support for larger Dynamic Type sizes across dense screens

## Session and Home resilience

- improved workout set row layout across phone sizes
- made session controls and active-session cards more resilient on compact and large phones
- improved visibility and behavior of current-set and active-rest states
- reduced cramped layouts and improved wrapping on key session and home screens

## Progress and summary resilience

- added accessible text summaries for progress insights and trends
- improved exercise progress detail readability without relying only on charts
- made progress cards and finish-summary sections adapt more gracefully to larger text
- improved low-data states so they remain clear and informative

# Changelog v2.0.1

## v2.0.1 — Session polish and trust pass

This release improves reliability, clarity, and overall trust in workout sessions without changing the app’s core workflow.

### 1. Resume and active-session reliability
- Improved resume behavior across Home and Calendar flows.
- Reopening an active workout is more consistent and more likely to land on the next actionable set.
- Reduced cases where a session existed but the app did not return to the expected place.

### 2. Better stale-session recovery
- Added clearer handling for older unfinished sessions.
- Stale sessions now offer safer recovery choices:
  - Resume
  - Finish now
  - Discard
  - Keep for later
- Improved suppression behavior so recovery prompts feel less repetitive.

### 3. Finish summary improvements
- Improved the end-of-session summary to better reflect what actually happened in the workout.
- Added or refined summary details such as:
  - completed sets
  - skipped sets
  - elapsed time
  - personal record highlights
  - segment-aware summary for warm-up, main, and cool-down

### 4. Export and backup polish
- Improved export naming and wording for better clarity.
- Cleaner support bundle / backup wording in user-facing flows.
- Better empty-state messaging when there is little or no data to export.

### 5. Copy and localization consistency
- Standardized wording across resume, recovery, finish, and export flows.
- Made warm-up / main / cool-down terminology more consistent.
- Improved localized text fit for compact layouts, including touched Spanish flows.

### Also in this release
- Test hardening and regression coverage for the updated session flows.
- General UI polish for trust-critical workout lifecycle screens.

# Changelog v2.0.0

## Phase 5

### PR 15

- Deferred calories explicitly to v2.0.1 to protect the v2.0.0 release candidate from late-scope risk
- Tightened UITestHost launch assertions so session and Progress smoke suites fail fast on invalid seed/route combinations
- Updated the v2.0.0 release checklist and release copy to match the shipped scope

### PR 14

- Improved accessibility across Progress, session, routine, and settings flows
- Polished v2 copy for clearer and more consistent terminology
- Hardened linked warm-up and cool-down workflow testing
- Improved regression stability for Progress and localized flows
- Strengthened UI test seed validation for release-ready smoke coverage

### PR 13 

- Added Spanish localization across key WorkoutTracker v2 flows
- Localized Progress dashboard and exercise detail experiences
- Localized linked warm-up and cool-down routine flows
- Improved locale-aware formatting for timers, counts, and progress displays
- Added localization smoke coverage for core v2 screens

## Phase 4

- Added a new Progress dashboard with strength, volume, consistency, and recovery insights
- Added exercise-specific Progress drill-down
- Improved honest low-data states across Progress
- Added focused UI smoke coverage for Progress flows

## Phase 3

- Built the foundation for the upcoming Progress Hub
- Added deeper workout analytics for consistency, volume, and exercise progress
- Introduced session efficiency tracking for rest timing and workout pacing
- Improved reliability of progress insights when workout history is limited
- Expanded internal test coverage for analytics and progress calculations

## Phase 2

- linked routine model
- segmentKind persistence on session exercises
- main stored as nil for backward-safe compatibility

## Phase 1

- Better groundwork for localization and future language support
- More consistent formatting for timers, dates, and values across the app
- Improved accessibility labels in core workout areas
- Smarter rest timer behavior during workouts
- Rest timer now stays visible when you go past the planned rest time
- Quick buttons to extend rest time instantly
- New settings for rest timer cues and overdue display
- Stronger test coverage for workout and timer flows
