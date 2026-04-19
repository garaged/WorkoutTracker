# v2.3.0 — Programs / progression / coaching

## Product goal
Move WorkoutTracker from session logging into long-term training guidance.

Core user promise:

> Given an assigned program and the user's recent results, the app can show where they are, what they should do next, and when they should repeat or deload.

## Scope
### In scope
- multi-week training programs
- user assignment of a program
- deterministic planner for current week/day and next action
- typed progression rules
- bundled and shareable JSON program packs
- adherence and gentle guidance UI

### Out of scope for v2.3.0
- remote program marketplace
- cloud sync for program packs
- fuzzy readiness / recovery intelligence
- arbitrary rule scripting or DSLs
- broad AI coaching language generation
- full autoregulation / RPE engine unless already required by existing data models

## Release principles
1. **Template vs runtime must stay separate**
   - `TrainingProgram` is a reusable template.
   - `ProgramAssignment` + `ProgramExecutionState` represent a specific user's runtime state.
2. **Deterministic before clever**
   - Recommendations should be explainable from assignment state, schedule, completion history, and rule evaluation.
3. **Reuse routines where possible**
   - Routines stay the structural workout definition.
   - Programs define when and how routines are used over time.
4. **Stable identity everywhere**
   - Program, week, day, prescription, and rule references should use stable identifiers.
5. **Honest adherence UI**
   - Planned, completed, missed, repeated, and deload states must not blur together.

## Architecture spine
- **Routine** = what a workout looks like
- **Program** = when and why routines/prescriptions are performed over weeks
- **Assignment** = a user following a specific program starting on a date
- **Execution state** = what actually happened
- **Planner** = what should happen next
- **Progression engine** = how targets change after results
- **Pack codec/validator** = how programs move in and out of the app

## PR sequence
1. `PR1-domain-and-assignment.md`
2. `PR2-planner-and-adherence.md`
3. `PR3-progression-engine.md`
4. `PR4-pack-import-export.md`
5. `PR5-programs-ui.md`

Do not jump ahead unless the prompt explicitly allows it.

## Seeded sample programs for development and tests
Start with only a few predictable programs:
- **Linear Strength 4-Week**
- **Hypertrophy Double Progression**
- **4th-Week Deload Program**

These are enough for core planner, adherence, and progression coverage.

## Integration expectations
### Home
Add a compact program surface only after the underlying planner/adherence model is trustworthy.

Recommended Home signals:
- current assigned program
- current week progress
- next recommended action
- gentle missed-session or deload cue

### Sessions
When a session is started from a program context:
- preserve program provenance on the session
- update program execution state on finish
- recompute recommendation after completion

## Migration and persistence concerns
- deleting a program template should not silently destroy execution history
- imported packs need versioned schema from day one
- routine deletion or mutation should fail gracefully for linked program days
- assignment history should remain readable even if source templates change later

## Acceptance standard for the release
- user can assign a program
- current week/day is accurate
- next recommended action is accurate
- missed sessions are visible and non-misleading
- repeat-week behavior is honest
- deload cues are understandable
- session completion updates program state correctly
- import/export validation is explicit and safe
- touched strings are localized and polished
