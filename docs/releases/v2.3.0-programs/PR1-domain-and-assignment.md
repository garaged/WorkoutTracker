# PR1 — Program domain and assignment foundation

## Goal
Introduce training programs as first-class domain objects with a strict split between:
- reusable template structure
- user-specific assignment and runtime state

## Must-have outcomes
- programs exist as multi-week, multi-day domain models
- assignments exist independently of templates
- runtime state does not leak into template models
- the model layer is ready for planner and progression services

## New files
- `workouttracker/Domain/Models/TrainingProgram.swift`
- `workouttracker/Domain/Models/ProgramWeek.swift`
- `workouttracker/Domain/Models/ProgramDay.swift`
- `workouttracker/Domain/Models/ProgramPrescription.swift`
- `workouttracker/Domain/Models/ProgramAssignment.swift`
- `workouttracker/Domain/Models/ProgramExecutionState.swift`
- `workouttracker/Domain/Models/ProgramCompletedDay.swift`
- `workouttracker/Domain/Models/ProgramMissedDay.swift`
- `workouttracker/Domain/Models/TrainingProgramTypes.swift`

## Existing files likely updated
- `workouttracker/Domain/Models/WorkoutRoutine.swift`
- `workouttracker/App/Seed/SeedCatalog.swift`
- `workouttracker/Resources/Localizable.xcstrings`

## Domain boundaries
### `TrainingProgram`
Should hold template-only data:
- identity
- metadata
- ordered weeks
- descriptive information
- bundled/import metadata

Should **not** hold:
- current week
- missed sessions
- last recommendation
- user adherence state

### `ProgramAssignment`
Owns user-specific tracking context:
- assigned program reference
- start date
- active / paused / completed status
- schedule anchor strategy
- execution-state linkage

### `ProgramExecutionState`
Owns what actually happened:
- current week/day pointer
- completed day records
- missed day records
- repeated weeks
- applied deloads

## Recommended modeling rules
- Use stable identifiers everywhere.
- Prefer small shared enums in `TrainingProgramTypes.swift`.
- Reuse routines by reference where practical.
- Snapshot display names when runtime/history resilience matters.

## Do not do in PR1
- planner logic
- progression logic
- pack import/export
- full Programs UI
- Home integration
- session-to-program completion wiring beyond minimal provenance groundwork

## Unit tests
Add focused tests for:
- structural ordering of weeks and days
- assignment initialization
- state transitions such as pause/resume/complete if implemented
- invalid or duplicate structure validation if initializers enforce it

Suggested files:
- `workouttrackerTests/Programs/TrainingProgramModelTests.swift`
- `workouttrackerTests/Programs/ProgramAssignmentModelTests.swift`

## Manual validation
- confirm at least one seeded program can exist
- confirm assignments can be created and loaded cleanly
- confirm migration does not break existing app data

## Acceptance criteria
- app builds with new models
- at least one seeded program template exists
- one assignment can be created and read back
- template/runtime boundaries are respected
- tests cover basic structural invariants
