# PR5 — Programs UI and coaching surface

## Goal
Expose Programs as a first-class feature area with calm, deterministic guidance.

## Must-have outcomes
- user can browse programs
- user can inspect a program before assignment
- user can assign a program
- progress screen shows current week/day, completion, and next action
- session completion feeds back into visible program state
- Home can surface a compact trusted summary

## New files
- `workouttracker/Features/Programs/ProgramLibraryScreen.swift`
- `workouttracker/Features/Programs/ProgramDetailScreen.swift`
- `workouttracker/Features/Programs/ProgramAssignmentScreen.swift`
- `workouttracker/Features/Programs/ProgramProgressScreen.swift`
- `workouttracker/Features/Programs/Components/WeekProgressCard.swift`
- `workouttracker/Features/Programs/Components/NextRecommendedActionCard.swift`
- `workouttracker/Features/Programs/Components/MissedSessionCard.swift`
- `workouttracker/Features/Programs/Components/DeloadCueCard.swift`
- `workouttracker/Features/Programs/Components/ProgramDayRow.swift`

Optional only if screen logic gets noisy:
- `workouttracker/Features/Programs/ViewModels/ProgramProgressViewModel.swift`

## Existing files likely updated
- `workouttracker/App/AppRootView.swift`
- `workouttracker/App/Routing/AppRoute.swift`
- `workouttracker/App/Routing/RouteResolver.swift`
- relevant Home feature files
- `workouttracker/Features/Sessions/WorkoutSessionScreen.swift`
- `workouttracker/Resources/Localizable.xcstrings`
- `workouttrackerUITestHost/workouttrackerUITestHostApp.swift`

## UI behavior
### Library
Show a compact list of available programs with:
- title
- duration
- goal/focus
- difficulty if available

### Detail
Show:
- overview
- week/day structure
- progression summary
- assign action

### Assignment
Keep choices simple:
- start date
- schedule anchor strategy if needed
- confirm assignment

### Progress
Show:
- current week/day
- completion this week
- missed sessions
- next recommended action
- repeat or deload cues when applicable

### Home
Add only a compact surface once planner/adherence is already trustworthy:
- current program
- week progress
- next recommended action
- gentle missed-session or deload cue

## Copy guidance
Use deterministic, calm language.

Good examples:
- "Week 2 is 3 of 4 sessions complete."
- "You missed Day 3."
- "Recommended next action: complete Day 3 before advancing."
- "Deload week starts next."

Avoid:
- alarmist recovery language
- vague motivational coaching
- misleading certainty

## UI tests
Seeded UI tests must use `workouttrackerUITestHost`.

Add or update:
- `workouttrackerUITests/ProgramsSmokeUITests.swift`
- `workouttrackerUITests/ProgramProgressionSmokeUITests.swift`
- `workouttrackerUITests/ProgramAdherenceSmokeUITests.swift`

Under `workouttrackerUITestHost/workouttrackerUITestHostApp.swift`:
- seed bundled program data
- seed at least one assignment scenario
- add `UITESTS_SEED`-gated fail-fast assertions for expected program/routine linkage

## Acceptance criteria
- Programs feature is navigable and understandable
- assignment flow works
- progress screen reflects real state
- session completion updates program state
- Home shows meaningful next-step guidance
- UI tests cover assign/follow/update paths
