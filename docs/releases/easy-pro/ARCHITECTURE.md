# EP2 architecture and executable policy contracts

This implements the accepted additive/shared-service direction. No application schema migration is part of the first policy slice.

## Policy slice

- ExperienceMode is a presentation preference, independent of entitlements and domain IDs. A persisted effective/requested pair keeps the current workout stable. Bootstrap requires explicit installation evidence; an empty history is insufficient to classify a new user. Existing starter-install/restore markers will provide that evidence at integration time.
- QuickStartStyle defines nine stable IDs and an unknown-value display fallback while retaining the raw value at the persistence boundary. No Apple Health mapping is implied by a style.
- QuickStartTimingState is a Codable value with idle/running/paused/completed phases, elapsed unpaused duration, interval anchor, monotonic clock epoch, revision, and applied command identity/action pairs. A command returns a proposed next value; callers must persist it successfully before publishing it to UI. Failed persistence therefore leaves the last committed value intact.
- A duplicate command with the same action is a no-op, even if its expected revision is old. Reusing an ID for a different action is an error. Other stale-revision commands are rejected. Terminal duplicate finish is a no-op. Pause/resume cannot reset a completed timer.
- A live clock epoch uses system uptime and wall-clock samples; a wall/monotonic discrepancy over 5 seconds or decreasing uptime requests recovery review. A new process epoch uses persisted wall-time anchors: negative elapsed or more than 12 hours of unattended running requires review. These thresholds apply to the new quick-start engine, not existing long hikes. Paused time is never counted. Cross-launch recovery does not silently finish a workout.
- Existing session/rest engines remain unchanged in this first slice. Integration will adapt the new value state to canonical tracked activity/session-exercise storage and typed backups; it must not create an alternate history database.

## Persistence integration gate

Before schema changes, add a versioned timing payload and explicit backup mappings to the existing canonical records. Freestyle belongs to WorkoutSession/WorkoutSessionExercise; standalone generic timers belong to TrackedActivitySession. Never persist the same time as a second synthetic workout. Define generic tracked-kind capabilities without walking fallback and gate unmapped Health export. Use the existing coordinated owner for phone/Watch commands; the pure reducer alone does not establish distributed ownership or atomic SwiftData persistence.

## Validation boundary

### Versioned timer persistence contract (EP-R10, EP-R12, EP-R14)

The canonical tracked record will store one optional encoded QuickStartTimingPayload. Version 1 contains the exact style raw ID and the timing value; it contains no metrics or duplicate history identity. Known styles resolve to the catalog; unknown nonempty IDs remain unchanged and use a generic presentation. Empty IDs, unsupported payload versions, malformed JSON, invalid clock anchors, negative/nonfinite duration, duplicate command IDs and inconsistent phase/revision/command history must fail decoding. Reading invalid data must not silently reset the timer or rewrite the original bytes. Legacy records without a payload keep their existing timing path. Typed backup export/import must carry the payload bytes unchanged before the adapter is enabled.

The payload validates structural timing integrity without estimating elapsed time. A structurally valid old anchor can still require explicit clock recovery when used. Payload validation alone is not migration or SwiftData round-trip evidence.

Swift policy tests are native XCTest fixtures and must run on the repository's Xcode CI before this slice is called verified. No local Swift compiler is available in this workspace. Test creation/inspection is not passing evidence. UI wiring, migration, Health/Watch behavior, and human validation remain pending until their own scenarios pass.
