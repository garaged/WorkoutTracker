# PR2 — Planner and adherence engine

## Goal
Turn program structure plus assignment state into deterministic guidance:
- where the user is now
- what day is next
- whether a week is complete
- whether missed work should be shown as recoverable, incomplete, or ready to repeat

## Must-have outcomes
- app can determine current week/day
- app can compute week completion honestly
- app can detect missed required sessions
- app can generate a typed next-action recommendation

## New files
- `workouttracker/Services/Programs/ProgramPlanner.swift`
- `workouttracker/Services/Programs/ProgramAdherenceService.swift`
- `workouttracker/Services/Programs/Models/ProgramPosition.swift`
- `workouttracker/Services/Programs/Models/PlannedProgramDay.swift`
- `workouttracker/Services/Programs/Models/ProgramAdherenceSummary.swift`
- `workouttracker/Services/Programs/Models/ProgramWeekCompletion.swift`
- `workouttracker/Services/Programs/Models/ProgramRecommendation.swift`

## Existing files likely updated
- `workouttracker/Services/Workouts/WorkoutSessionService.swift`
- `workouttracker/Domain/Models/WorkoutSession.swift`
- `workouttracker/App/Routing/AppRoute.swift`
- `workouttracker/App/Routing/RouteResolver.swift`

## Planner rules to lock down
- assignment start date anchors week progression
- planned weekdays are only used when present and explicitly supported
- incomplete required days remain visible; do not silently pretend they were done
- week completion requires completion of all required days

## Recommendation style
Recommendations should be typed values, not arbitrary strings.

Good initial recommendation kinds:
- start week
- advance to next day
- complete missed day
- repeat week
- deload next
- complete program
- resume today

## Do not do in PR2
- progression rule evaluation
- JSON pack import/export
- broad Programs UI beyond small plumbing helpers if absolutely required

## Unit tests
Suggested files:
- `workouttrackerTests/Programs/ProgramPlannerTests.swift`
- `workouttrackerTests/Programs/ProgramAdherenceServiceTests.swift`

Cover:
- current position on start date
- next day selection
- week completion
- missed-day detection
- behind-schedule state
- recoverable vs incomplete classification

## Manual validation
- assign a seeded program with known weekdays or sequence order
- complete one day and confirm progress updates
- leave one required day incomplete and confirm guidance stays honest

## Acceptance criteria
- planner returns current and next program position deterministically
- adherence service reports completed and missed days correctly
- recommendation output is UI-independent and typed
- tests cover date alignment and missed-session behavior
