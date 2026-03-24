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
