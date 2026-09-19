# EP2 architecture and executable policy contracts

This implements the accepted additive/shared-service direction. No application schema migration is part of the first policy slice.

## Policy slice

- ExperienceMode is a presentation preference, independent of entitlements and domain IDs. A persisted effective/requested pair keeps the current workout stable. Bootstrap requires explicit installation evidence; an empty history is insufficient to classify a new user. Existing starter-install/restore markers will provide that evidence at integration time.
- QuickStartStyle defines nine stable IDs and an unknown-value display fallback while retaining the raw value at the persistence boundary. No Apple Health mapping is implied by a style.
- QuickStartTimingState is a Codable value with idle/running/paused/completed phases, elapsed unpaused duration, interval anchor, monotonic clock epoch, revision, and applied command identity/action pairs. A command returns a proposed next value; callers must persist it successfully before publishing it to UI. Failed persistence therefore leaves the last committed value intact.
- A duplicate command with the same action is a no-op, even if its expected revision is old. Reusing an ID for a different action is an error. Other stale-revision commands are rejected. Terminal duplicate finish is a no-op. Pause/resume cannot reset a completed timer.
- A live clock epoch uses continuous monotonic and wall-clock samples; a wall/monotonic discrepancy over 5 seconds or decreasing monotonic time requests recovery review. The production adapter uses Swift ContinuousClock, which continues through system sleep; the payload's `uptime` field holds seconds from a process-local continuous-clock origin. A new process epoch uses persisted wall-time anchors: negative elapsed or more than 12 hours of unattended running requires review. These thresholds apply to the new quick-start engine, not existing long hikes. Paused time is never counted. Cross-launch recovery does not silently finish a workout. See [Apple ContinuousClock documentation](https://developer.apple.com/documentation/swift/continuousclock/continuous).
- Existing session/rest engines remain unchanged in this first slice. Integration will adapt the new value state to canonical tracked activity/session-exercise storage and typed backups; it must not create an alternate history database.

## Persistence integration gate

Before schema changes, add a versioned timing payload and explicit backup mappings to the existing canonical records. Freestyle belongs to WorkoutSession/WorkoutSessionExercise; standalone generic timers belong to TrackedActivitySession. Never persist the same time as a second synthetic workout. Define generic tracked-kind capabilities without walking fallback and gate unmapped Health export. Use the existing coordinated owner for phone/Watch commands; the pure reducer alone does not establish distributed ownership or atomic SwiftData persistence.

## Validation boundary

### Experience preference persistence contract (EP-R01–EP-R03)

ExperiencePreferenceStore is a versioned UserDefaults-backed presentation preference; it contains no workouts, entitlements or feature access. The first bootstrap uses explicit installation evidence from the pre-seed starter-pack marker: new installations default to Easy and upgrades default to Pro even with zero workout history. A saved choice always wins over later bootstrap evidence. Invalid or unsupported preference data falls back once from the same explicit evidence and is replaced with a valid snapshot.

Mode changes requested during any active tracked or strength session persist as pending and apply only after all sessions become idle; selecting the effective mode cancels a pending change. Both shells use the same ModelContainer, services, routes and domain IDs. Pro remains the existing shell; Easy is an additive presentation. Store tests must pass before AppRootView or Settings consumes it.

### Canonical recorder transaction contract (EP-R12–EP-R14)

QuickStartRecorder performs synchronous MainActor commands against the caller's canonical ModelContext. It refuses a context with unrelated pending edits; only a clean starting context may be rolled back after an injected or real save failure. Compute and encode a validated proposed payload before changing the record, publish success only after save, and restore committed state on failure. The injected save seam exists for deterministic disk-failure tests.

A start command's UUID is the canonical record UUID. Retrying the same ID/style returns that record; reusing the ID with a different style fails. Any unfinished strength session or active tracked session blocks a different start and returns the exact conflicting IDs. Lifecycle commands check revision and command identity through the timing policy. Legacy scalar duration, interval anchor, lifecycle and dates mirror the committed payload so history keeps one record. No sets, calories, distance or steps are inferred. Persistence/reopen/fault tests are required before UI or phone/Watch callers use this adapter. This is a single-process transaction boundary, not a claim of distributed locking.

### Versioned timer persistence contract (EP-R10, EP-R12, EP-R14)

The canonical tracked record will store one optional encoded QuickStartTimingPayload. Version 1 contains the exact style raw ID and the timing value; it contains no metrics or duplicate history identity. Known styles resolve to the catalog; unknown nonempty IDs remain unchanged and use a generic presentation. Empty IDs, unsupported payload versions, malformed JSON, invalid clock anchors, negative/nonfinite duration, duplicate command IDs and inconsistent phase/revision/command history must fail decoding. Reading invalid data must not silently reset the timer or rewrite the original bytes. Legacy records without a payload keep their existing timing path. Typed backup export/import must carry the payload bytes unchanged before the adapter is enabled.

The payload validates structural timing integrity without estimating elapsed time. A structurally valid old anchor can still require explicit clock recovery when used. Payload validation alone is not migration or SwiftData round-trip evidence.

### Neutral activity-kind integration (EP-R10, EP-R11)

Add a generic tracked activity kind with duration-only capabilities and unspecified environment. Unknown stored kind IDs resolve to this neutral presentation without changing the stored raw ID. The existing activity picker keeps its four supported specialized kinds; the dedicated quick-start picker owns generic styles. Generic/unknown kinds have no implicit Health mapping and must fail before a Health save request. Unsupported Watch start-kind values are rejected rather than substituted with walking. These changes do not enable a new recording screen or alter existing specialized tracking behavior.

Swift policy tests are native XCTest fixtures and must run on the repository's Xcode CI before this slice is called verified. No local Swift compiler is available in this workspace. Test creation/inspection is not passing evidence. UI wiring, migration, Health/Watch behavior, and human validation remain pending until their own scenarios pass.


### Freestyle exercise interval and next-transition contract (EP-R05–EP-R09)

Gym Freestyle stores one canonical `WorkoutSession` and one independent interval per `WorkoutSessionExercise`. The additive persisted fields are `freestyleStartedAt`, `freestyleEndedAt`, and `freestyleStartedSessionElapsedSeconds`. The session-elapsed baseline makes an exercise duration exclude a workout-level pause without copying pause state into every child: on explicit start, capture both the wall-clock anchor and the current unpaused session elapsed value; on explicit finish, persist `max(0, session.elapsedSeconds(now) - baseline)` and the end anchor.

There is no active exercise interval while the next-exercise picker is shown. That between-exercises period remains part of the workout’s elapsed duration but not any exercise’s duration. Canceling the picker changes no model. Starting a catalog or unnamed next exercise appends exactly one new child at `max(order) + 1`; its session-exercise ID is always new, even when it snapshots the same catalog exercise ID. An unnamed entry receives a new session-local generic exercise ID and never creates or mutates a catalog record.

Finish is idempotent for an already ended child at the model-command boundary; it never starts a replacement. A replacement is created only by the explicit Start action. The first implementation keeps duration-only tracking for both unnamed and directly selected catalog exercises: it creates no planned set rows and no inferred measurement/rest. Backup/export changes for these persisted interval fields must ship in the same EP4 persistence slice; older records with all three fields absent remain readable as legacy session exercises.
