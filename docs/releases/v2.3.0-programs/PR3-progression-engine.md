# PR3 — Progression engine

## Goal
Adjust prescriptions based on actual results using a constrained, typed set of progression rules.

## Must-have outcomes
- progression rules are typed and explainable
- success, hold, repeat, and deload paths are supported
- rule evaluation is deterministic and testable without UI

## New files
- `workouttracker/Domain/Models/ProgressionRule.swift`
- `workouttracker/Services/Programs/ProgressionEngine.swift`
- `workouttracker/Services/Programs/Models/ProgressionDecision.swift`
- `workouttracker/Services/Programs/Models/ProgramPrescriptionAdjustment.swift`

## Existing files likely updated
- `workouttracker/Domain/Models/WorkoutSession.swift`
- `workouttracker/Features/Sessions/WorkoutSessionScreen.swift`
- possibly `workouttracker/Services/Workouts/WorkoutSessionService.swift`

## Supported rule set for v2.3.0
Keep the first shipping set intentionally small:
- increase load after success
- repeat week after failure threshold
- deload every N weeks
- double progression
- hold

## Strong implementation rule
Use typed enums or strongly typed value objects.

Do **not** build:
- a generic rule DSL
- scriptable expressions
- overly broad automation that the UI cannot explain clearly

## Decision output
Every progression result should answer:
- what action was taken
- why it was taken
- what target changed
- what target stayed the same

## Do not do in PR3
- broad pack import/export work
- full Programs UI
- speculative analytics coupling

## Unit tests
Suggested files:
- `workouttrackerTests/Programs/ProgressionEngineTests.swift`
- `workouttrackerTests/Programs/ProgressionRuleTests.swift`

Cover:
- successful completion increases target
- partial completion holds target when expected
- failure threshold triggers repeat recommendation
- scheduled deload applies correctly
- double progression only raises load after rep target is maxed
- invalid rule config fails safely

## Manual validation
- complete a seeded success week and confirm next prescription adjusts upward
- fail a seeded target and confirm repeat-week guidance appears
- reach a deload interval and confirm deload cue + adjusted targets

## Acceptance criteria
- progression engine works without UI dependencies
- supported rules are constrained and typed
- decisions are explainable
- tests cover success, hold, repeat, and deload paths
