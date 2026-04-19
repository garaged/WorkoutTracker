# v2.3.0 testing plan

## Test strategy
Keep tests aligned with the PR sequence. Do not try to land the whole release before adding coverage.

## PR1
### Unit tests
- `workouttrackerTests/Programs/TrainingProgramModelTests.swift`
- `workouttrackerTests/Programs/ProgramAssignmentModelTests.swift`

### Focus
- ordering and structure validation
- assignment initialization
- state transitions if implemented
- migration sanity for existing app data

## PR2
### Unit tests
- `workouttrackerTests/Programs/ProgramPlannerTests.swift`
- `workouttrackerTests/Programs/ProgramAdherenceServiceTests.swift`

### Focus
- current position
- next day selection
- week completion
- missed-day detection
- behind-schedule / recoverable classification

## PR3
### Unit tests
- `workouttrackerTests/Programs/ProgressionEngineTests.swift`
- `workouttrackerTests/Programs/ProgressionRuleTests.swift`

### Focus
- increase after success
- hold after partial completion
- repeat-week trigger
- scheduled deload
- double progression behavior
- invalid config handling

## PR4
### Unit tests
- `workouttrackerTests/Programs/ProgramPackCodecTests.swift`
- `workouttrackerTests/Programs/ProgramPackValidatorTests.swift`

### Focus
- round-trip encode/decode
- schema version enforcement
- malformed JSON
- duplicate ids
- missing references
- invalid rule configuration

## PR5
### UI tests
- `workouttrackerUITests/ProgramsSmokeUITests.swift`
- `workouttrackerUITests/ProgramProgressionSmokeUITests.swift`
- `workouttrackerUITests/ProgramAdherenceSmokeUITests.swift`

### Critical UI-test rule
Any seeding or fail-fast validation for UI tests belongs under:
- `workouttrackerUITestHost/` (usually `workouttrackerUITestHostApp.swift`)

Not under the main app target.

### Seed validation
If a test depends on seeded programs, routines, or assignments:
- guard it with `UITESTS_SEED`
- fail fast with a clear message if the data is missing

## Manual validation checklist
- browse seeded programs
- assign a seeded program
- verify current week/day
- complete one program-linked session
- verify week progress updates
- leave one required day incomplete and verify missed-state UI
- verify deload or repeat cues where seeded
- verify import/export round-trip for program packs
- verify touched strings are localized and polished

## Release gate
Before calling v2.3.0 done, confirm:
- program assignment works
- planner is accurate
- adherence is honest
- progression is explainable
- pack import/export is safe
- Home/session integration reflects real program state
- seeded UI tests pass reliably
