# Behavioral specification

Status: proposed. All MUST statements become accepted requirements only after the product/specification approval gate. IDs are stable; scenarios and milestone owners are in [TRACEABILITY.json](TRACEABILITY.json).

## Experience and entry

### EP-R01 — Shared data, reversible mode

Easy and Pro MUST operate on the same canonical workout, exercise, program and activity records. Switching MUST preserve IDs, values, preferences and access to corrections/export. Mode is not authorization and must not filter records out of history. New installs recommend Easy; existing installations retain Pro. Install/restore detection must use an audited marker, not "has zero workouts." Active-session presentation is pinned; a requested mode applies to new entry after the active session finishes. Persist effective and requested preferences separately and recover them after restart.

### EP-R02 — Three discoverable starts

Today MUST expose Follow a workout, Gym freestyle and Just start a timer without mandatory planning. Resume takes primary position when work is active; quick-start options remain accessible. Tracking setup must not ask for Health, location or notification permission before the user needs that capability. Existing program/routine/library/calendar/body/settings destinations remain reachable via the destination matrix in README and the EP1 screen inventory.

### EP-R03 — Fast and stable selection

Exercise/style pickers MUST present a bounded set of up to four favorite/recent choices, plus Search/More as appropriate. Favorite order is stable; recents follow last successfully committed start and are deduplicated by stable ID. Names/notes are snapshots and localized display labels are not identity. Deleted/unavailable recent references must show a recovery path or generic fallback, never crash or substitute a different exercise silently. A direct Start [choice] action commits and starts once; browsing does not start anything.

### EP-R04 — Guided behavior preserved

Follow a workout MUST retain ordered warm-up/main/cool-down, instructions, suggestions versus actuals, explicit skip, rest, correction, save and interrupted resume. Program-launched sessions retain their source provenance and existing rules. Missing starter/program references block only the affected action and explain recovery; never replace a prescribed exercise silently.

## Gym freestyle

### EP-R05 — Start without a routine

Starting an exercise MUST create or append to one freestyle workout session without routine/program construction. The first committed exercise starts the workout and its exercise clock. Subsequent exercises append in stable order under that same session. Session-exercise identity is unique even when the same catalog exercise is used twice. A quick-start launch must not auto-create planned strength rows and then count them as performed.

### EP-R06 — Unknown exercise is a valid start

Start unnamed exercise MUST create a session-local generic exercise with a stable identity and readable snapshot. Naming it later changes only that entry unless the user explicitly chooses a catalog operation. Creating a catalog exercise is optional. Blank/whitespace-only edits retain the generic label; no raw user text becomes a route, query, identifier or executable content.

### EP-R07 — Finish and move on explicitly

Finish exercise MUST stop its exercise interval and active rest, durably record completion and keep completed sets. Next exercise opens the picker in a between-exercises state. Canceling the picker must not create a placeholder, restart the finished interval or lose the completed entry. Start [next] is the only transition that starts the next interval. Repeated finish/start input and phone/Watch races must produce at most one transition per command ID.

### EP-R08 — Optional metrics, honest completion

A freestyle exercise MAY finish with duration and no sets. Actual repetitions, weight, distance and energy MUST remain absent unless explicitly entered or acquired from a supported measurement source. A completed exercise is not a completed set, a volume measurement or a personal record. Unknown load is distinct from explicitly entered zero/bodyweight. Correcting a completed set or exercise duration must use existing editability rules and preserve unit semantics; unsafe edits while recording are rejected or coordinated atomically.

### EP-R09 — Rest is separate from progression

Logging a freestyle set MAY start the configured rest timer; a duration-only start MUST NOT invent rest intervals or sets. Continue/Finish rest retains existing timer behavior and cannot auto-complete the exercise. Finish exercise/finish workout MUST terminate its associated rest and notifications. Leaving the foreground must not duplicate callbacks or transfer a rest timer to an unrelated exercise.

## Style / video timer

### EP-R10 — Generic timer presets

The nine proposed categories in README MUST be represented with stable IDs and localized labels. Cardio, weights/machines strength, bodyweight/functional and HIIT are the initial visible defaults; More holds the remaining choices. Start [style] immediately starts a count-up timer, subject only to active-session resolution. Target duration, a video link, exercise catalog and sensor permission are optional. One style timer produces one canonical activity record; no duplicate parallel workout record is created for the same exercise time.

Proposed stable style IDs: `cardio`, `strength_weights`, `bodyweight_functional`, `hiit`, `dance_fitness`, `yoga`, `pilates`, `mobility_stretching`, `other`. These IDs describe app categories, not Apple Health enum names.

### EP-R11 — Video independence

Switching to YouTube, another app, or locking the screen MUST preserve the timer's recording state. No video playback state or content is inspected or inferred. Quick timers do not request audio focus or introduce cues that interrupt other playback; explicit existing audio preferences remain respected in other flows. Returning shows current elapsed active time. Video completion does not complete the workout automatically.

### EP-R12 — Timing definitions and recovery

Time MUST be derived from persisted interval state, never accumulated display ticks. While a process is live, elapsed measurement uses a monotonic clock; persistence retains wall-clock anchors for cross-launch recovery. Explicit pause stops accrual; background/lock alone does not pause. On relaunch, reconstruct from the persisted state; backwards timestamps, unreasonable gaps, or a detected clock discontinuity require a readable recovery/correction decision rather than silently counting bad time. Live measurements never become negative. Fake clock tests exercise boundaries without real sleeps.

Terminology MUST be consistent:
- Workout active duration: all unpaused session time, including rests and between-exercise selection.
- Exercise elapsed duration: unpaused time from explicit exercise start to explicit exercise finish, including rests within that exercise. It is not "muscle working time" or time under tension.
- Rest duration: a labeled overlapping subset of exercise/session duration; never added again to totals.
- A pause at the workout level pauses the current exercise interval and associated rest accounting coherently; resume preserves their ownership.
- Standalone style active duration: unpaused timer intervals only.
- Exercise sums can be less than workout duration because selection/transitions occupy time. Analytics must not add session and exercise durations together.

## Shared lifecycle and integrity

### EP-R13 — Active-session conflicts

Quick starts MUST allow only one running quick-start session across coordinated phone/Watch entry points. If any relevant native session is active, show Resume existing or Finish existing and start new; the latter commits existing completion first and creates the new record only after that succeeds. Cancel leaves the original untouched. A paused session counts as active for conflict selection. Legacy multiple-active states remain recoverable through a chooser; this feature must not delete or merge them. Explicit external links still resolve their exact session ID; they are not redirected to the most recent arbitrary session.

### EP-R14 — Atomic commands and persistence failures

Start, pause, resume, finish, correction and finish-then-start MUST be governed by explicit state transitions with command identities/revision checks. Successful completion is shown only after persistence succeeds. A failed save preserves a retryable representation and does not show Saved or advance to an uncommitted next exercise. Retrying the same command must not duplicate history, time, sets or Health export. Cross-device control uses established ownership/coordination; unsupported concurrency must fail visibly without silently overwriting newer state.

### EP-R15 — Finish, abandon and correction

Finishing a workout MUST close all open intervals, preserve entered records, stop associated timers/notifications and save exactly one summary. Unstarted exercises are not completed; duration-only work remains distinct from skipped work. Discard is explicit and destructive with confirmation/undo consistent with current behavior. Finishing with no meaningful recorded activity must not inflate completion/adherence/PR counts; summary truthfully reports empty or partial work. History correction must recompute affected summaries and preserve dirty/export reconciliation state.

### EP-R16 — Honest analytics and program isolation

History MUST distinguish guided, freestyle and generic timed activity while remaining searchable/inspectable in both modes. Duration-only work counts as activity time, never fabricated reps/volume/calories/records. A quick start MUST NOT advance a program assignment unless launched through an explicit existing program context with preserved provenance. Timing and analytics aggregation must avoid duplicate records across session/exercise/style representations.

### EP-R17 — Additive schema and portable data

Schema/category changes MUST preserve existing IDs, snapshots, raw category values, backup/import/export and restore behavior. New generic styles must not fall through to walking or another category. Unsupported raw values retain a readable Unknown/Other presentation and original raw value; unsafe export is unavailable with an explanation. Snapshot name/history remains valid after catalog deletion. Test legacy fixtures and new-data round trips. Document that an older app may not read new-format data; never promise downgrade compatibility without evidence. Export a supported backup before a migration; avoid destructive rollback. Follow `docs/backup-schema.md`: retain typed export, domain UUIDs, explicit relationship references and ordering; update BackupManifest, BackupService mappings and round-trip regression tests for any persisted graph extension. Malformed pre-fix backups are not promised to restore; test explicit rejection/diagnostics separately from supported legacy-format migration.

### EP-R18 — Health and sensor mapping

App style labels MUST be mapped explicitly to supported Apple Health semantics in a reviewed mapping table; do not equate user terms with platform enum names by assumption. Where there is no faithful mapping, preserve the local record and explain unavailable export. Existing valid auto-save preferences apply only after mapping and idempotency are proven. Permission denial does not block local use. Generic indoor timers do not request GPS or invent distance/steps/energy. Source changes after export follow existing reconciliation behavior. Retry must not create duplicate Health records.

### EP-R19 — System surfaces and identity

Watch, widgets, Live Activities, Shortcuts and deep links MUST refer to the same canonical record and valid action state. Repeated/stale external actions must be safe no-ops or readable failures. A finish command from one surface reconciles all other controls; an external route to a guided rest retains the rest destination even in Easy. Availability follows existing per-device capabilities; unsupported new actions must not be advertised as working.

### EP-R20 — Accessibility, localization and low-friction use

New paths MUST support English and Spanish, VoiceOver, large text, reduced motion, keyboard/pointer on supported devices and iPhone/iPad layouts. Start/finish/pause actions have explicit labels and adequate touch targets. Timer announcements must not speak every second. Measured usability targets are: prepared recent exercise/style starts within two taps from Today when no conflict; first-time generic timer within three taps; next recent exercise within two taps from a finished-exercise view. Search typing is measured separately. Owner impressions are recorded separately from novice acceptance.

## Specification-driven delivery

### EP-R21 — Intent before implementation

Every milestone MUST carry intent, accepted behavior, non-goals, scenarios, architecture impact, dependencies and exit evidence before its implementation begins. Product agreement for this revision is a hard entry gate. A changed behavior requires its spec and affected acceptance scenarios to change first; code must not redefine expected results to make tests pass. A signed-off subset can be implemented without approving unrelated future changes.

### EP-R22 — Machine-checkable traceability

Each requirement MUST map to an intent, scenario, milestone, planned validation layer and eventually real implementation/test references. References are planned until files/tests exist and have been inspected. Completion requires current-commit results and manual evidence where needed; missing/skipped/blocked is not passed. Specification validation checks schema, unique IDs, reference integrity, cycles, approved status, links, nonempty Given/When/Then and completion evidence. Invalid specification fixtures must prove the validator rejects defects.

### EP-R23 — Meaningful code validation

Changes MUST include failing behavioral tests before implementation, then passing unit/integration tests and relevant build/UI regression evidence. Timing, crash recovery, retries, null metrics, migration and permission failures are first-class scenarios. Test value comes from checking observable outcomes and invariants, not matching private implementation structure or chasing a coverage percentage. No blanket retry may conceal a failing critical scenario.

### EP-R24 — Test-host and release integrity

UI tests MUST launch workouttrackerUITestHost, with all UITESTS_SEED fixtures and fail-fast assertions under workouttrackerUITestHost/**. Before UI-test work, request current relevant test/host files; failing runs additionally require screenshots and accessibility hierarchy attachments. Reuse working navigation/selector patterns. Release requires current evidence for changed flows plus Pro, migration, system-surface, accessibility and localization regressions. Native release cannot be approved solely from the browser prototype.

## Lifecycle transition contract

| Current state | Command | Next state | Required durable effect |
|---|---|---|---|
| No session | Start exercise/style | Running | One record, anchor and command identity |
| Freestyle exercise running | Finish exercise | Between exercises | Close exercise/rest; retain session |
| Between exercises | Open/cancel picker | Between exercises | No new exercise/interval |
| Between exercises | Start exercise | Exercise running | Append one identified entry and anchor |
| Running | Pause | Paused | Close active intervals once |
| Paused | Resume | Running | New interval anchor without counting paused time |
| Running/paused/between | Finish workout | Completed | Close intervals, persist one summary, synchronize surfaces |
| Any mutable state | Failed write | Same committed state + retryable pending action | No false success, duplicate or discarded input |
| Completed | Stale start/pause/finish | Completed | No mutation; safe response |
| Completed | Permitted correction | Completed | Recomputed summary/export reconciliation |

These are domain contracts, not a mandate to add a new workflow framework. Use existing services and isolate new policy/state only where required.
