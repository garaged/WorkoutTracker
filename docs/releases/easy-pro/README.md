# Easy / Pro: exercise first, detail when useful

Status: **proposed revision, awaiting product agreement**. No native implementation is authorized by this specification alone.
Revision: 2026-09-09. Release version: unassigned until scope is agreed.

## Start here

1. This document: user intent, proposed app form, decisions and source findings.
2. [BEHAVIOR.md](BEHAVIOR.md): normative behavior and data contracts.
3. [MILESTONES.md](MILESTONES.md): spec-first delivery and exit gates.
4. [VALIDATION.md](VALIDATION.md): specification checks, test strategy, CI and manual evidence.
5. [TRACEABILITY.json](TRACEABILITY.json): requirement → scenario → milestone → planned test mapping. Implementation/evidence fields are intentionally empty.

These release documents belong under `docs/releases/easy-pro/`, following repository AGENTS.md. They become the native release's source of truth after approval. The earlier browser prototype is a design reference, not a native specification or passing test. Its narrower, Site-hosted specification does not govern this expanded release.

## User evidence and authority

- Previously approved: one app, Easy and Pro presentations, shared data, and validating the guided experience before broad native changes.
- 2026-09-09: owner reports the prototype workflow looks very easy to use. This is positive owner feedback, not five novice usability sessions or native validation.
- Requested expansion: more quick starts; choose a machine/exercise spontaneously, start, finish and choose the next; start a generic exercise-style timer while following a YouTube workout.
- Requested engineering process: intent- and specification-driven milestones, robust specification/code validation, agreement on the new app form before implementation.
- Current authorization: write and review specifications. No feature code, UI-test code, CI implementation, native release, or prototype redesign is included in this revision.

## Intent catalog

| ID | User intent | Observable outcome |
|---|---|---|
| I-01 | Exercise without designing a program | Start a ready-to-use guided workout and understand each step |
| I-02 | Train spontaneously in a gym | Start an exercise, optionally log details, finish it and start another without leaving the session |
| I-03 | Follow a video or personal training style | Choose a style and start a visible timer without a routine, exercise list, or video URL |
| I-04 | Keep an honest record with little typing | Preserve measured duration and explicitly entered values; missing detail stays missing |
| I-05 | Choose simplicity without losing capability | Modes share history, recovery, programs and integrations; experienced users retain their workflow |
| I-06 | Trust each increment | Every change has accepted intent, behavioral scenarios, implementation traceability and current validation evidence |

## Proposed app form

One app. Easy/Pro are experience preferences, not separate apps, accounts or payment entitlements. Easy is useful permanently; Pro retains full planning/editing/analytics. Both modes can use quick starts.

Easy navigation remains **Today / Workouts / Progress**, plus a persistent Settings entry. Today prioritizes Resume when there is an active session. Otherwise show three clear choices, with a remembered/recent choice able to become the primary shortcut:

| Entry | User-facing explanation | Main loop |
|---|---|---|
| Follow a workout | Tell me what to do next | Choose a prepared workout → guided exercises → summary |
| Gym freestyle | Choose exercises as I go | Start an exercise → optional sets → finish exercise → next exercise → finish workout |
| Just start a timer | I already know what I want to do | Choose a style → timer → pause/resume → finish |

Quick-start access uses up to four recent/favorite choices at the top of the relevant picker. Stable favorites precede deduplicated recents; overflow is under More. Empty recents use curated defaults. No large catalog, account, schedule, target duration, equipment questionnaire or mandatory numeric input blocks the first start.

### Gym freestyle

Open the exercise picker directly. Recent/favorite exercises have an explicit **Start [exercise]** action. Search and equipment filters are optional. Selecting a search result uses the same explicit start action; there is no routine builder in this path.

An unrecognized machine is not a blocker: **Start unnamed exercise** starts a session-local "Gym exercise" entry, which can be named or classified later. No camera recognition, QR scanning, AI identification or mandatory catalog creation is proposed.

The active screen shows the exercise name, elapsed exercise time, optional Add set, and **Finish exercise**. After finish, show **Next exercise** and **Finish workout**. Next opens the picker; only an explicit start commits the next exercise and starts its timer. A planned shortcut can combine Finish exercise and opening that picker, but never invent a next exercise or start it while the user is choosing.

Logging duration alone is a valid result. Reps and load can be entered for a set when desired. Easy never demands invented counts or fills actuals from catalog defaults. "Finished exercise" must not imply that a target number of sets was performed.

### Video / style timer

Display the four defaults **Cardio**, **Strength · weights & machines**, **Bodyweight & functional**, and **HIIT**. More contains **Dance fitness**, **Yoga**, **Pilates**, **Mobility & stretching**, and **Other**. These are proposed product categories, not a researched popularity ranking or automatically equivalent Apple Health workout types.

Each button is labeled **Start [style]** and starts immediately when there is no active-session conflict. Labels can later be localized or renamed without changing the stable category identity. A short optional note may be added after start or finish; a URL is never required.

Users open or continue YouTube independently. No embedded player, downloading, automatic video detection, video-duration matching, browser permissions, autoplay or new audio takeover is in scope. Returning to YouTube must not reset the timer. The app records the chosen style and elapsed active time, not inferred video completion, repetitions or calories.

### Progress

Use a common history entry point with truthful labels: guided workout, freestyle workout, or timed activity. An unnamed exercise remains readable after catalog changes. Duration-only strength does not generate strength volume, records, calorie estimates, or automatic program adherence.

## Proposed decisions for agreement

| Decision | Recommendation | Why |
|---|---|---|
| D-01 | Keep all three start paths within the same Easy experience | Covers planned, spontaneous and video exercise without another mode |
| D-02 | Make exercise-level timing the minimum freestyle record; sets optional | Fits discovering a machine and moving on quickly |
| D-03 | Use the proposed nine styles, with four visible defaults | Broad coverage without a crowded first screen |
| D-04 | Interpret the requested strength variants as weights/machines versus bodyweight/functional | Clearer novice language; this interpretation needs owner agreement |
| D-05 | Allow one running quick-start session across phone/Watch entry points; resolve existing sessions explicitly | Avoid accidental overlapping timers and duplicated totals |
| D-06 | Keep video playback external and independent | The user can start immediately without video integration work |
| D-07 | Keep new-start convenience in Pro as well as Easy | Simplicity of entry is valuable at every experience level |
| D-08 | Adopt the spec-first milestones and required evidence gates below | Prevent attractive UI from outrunning behavior and compatibility |

These recommendations are not silently accepted by the earlier prototype approval. Product agreement should identify this document revision and D-01 through D-08. Revised decisions require affected requirements and scenarios to be updated before implementation.

## Source-grounded integration audit

Repository: https://github.com/garaged/WorkoutTracker
Inspected main commit: `6877003faf70f15534d25a723ef92758a5ff5b70`.

| Existing path | Finding | Consequence |
|---|---|---|
| `workouttracker/App/AppRootView.swift` | Current Home offers nine tiles; compact/split navigation and shared route handling exist | Keep Pro paths; add Easy navigation without replacing bootstrap or route resolution |
| `workouttracker/Services/Workouts/SessionResumePlanner.swift` | Existing active-session ordering and set/rest targets | Reuse routing; add a policy above it for conflict handling without changing explicit targets |
| `workouttracker/Domain/Models/Workouts/ExerciseTrackingStyle.swift` | Strength, reps-only, timed, time/distance, distance and notes styles exist | Reuse tracking semantics; quick starts must not inherit default three planned strength rows as actual work |
| `workouttracker/Domain/Models/Workouts/WorkoutSessionExercise.swift` | Snapshot identity, style, optional duration and set relationships exist | Preserve catalog snapshots; audit an additive persisted exercise lifecycle/interval extension |
| `workouttracker/Domain/Models/Workouts/WorkoutSetLog.swift` | Actual reps/load are optional; target and actual values are distinct | Preserve null values and their distinction from targets |
| `workouttracker/Services/Workouts/WorkoutLoggingService.swift` | Shared set mutation and undo commands exist | Adapt guided/freestyle UI to shared commands rather than duplicate logging logic |
| `workouttracker/Domain/Models/Activities/TrackedActivityKind.swift` | Only walking/running/hiking/yoga are supported | Generic styles need an explicit additive category/mapping design |
| `workouttracker/Domain/Models/Activities/TrackedActivitySession.swift` | Pause/resume timing exists; unknown raw kind currently falls back to walking | Prevent new or unsupported categories being mislabeled as walking; define compatibility before schema changes |
| `docs/backup-schema.md` | Typed workout graph export is mandatory; pre-fix malformed backups are not guaranteed restorable | Extend explicit manifest/mappings/round-trip tests; do not substitute reflection-only export |
| `.github/workflows/ios.yml` | PR/main unit tests; manually dispatched UI tests; no spec-validation job | Add spec and bounded critical UI gates after approval; current CI is not evidence of those proposed gates |
| `docs/releases/v2.3.0-programs/EXECUTION_PLAN.md` | Program provenance and finish/adherence behavior are defined | Quick starts must not silently advance a program assignment |

The new API/schema design must be reviewed in EP2 before code. Do not treat the browser prototype's localStorage model as a migration template.

## Out of scope for this release proposal

Separate paid/free products; automatic machine recognition; coaching prescriptions inferred from machine names; video hosting/integration; AI workout generation; new cloud sync; replacing program algorithms; competitive streak pressure. Existing exercise, program, sensor, permission, backup and accessibility capabilities remain supported.
