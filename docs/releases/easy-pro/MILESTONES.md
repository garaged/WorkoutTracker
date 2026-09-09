# Spec-first milestones

This sequence replaces the preliminary browser-prototype E0–E5 outline for the expanded release. EP0–EP6 IDs are distinct and used in TRACEABILITY.json. Every milestone has a specification phase before a code phase. Live implementation states and evidence are recorded in TRACEABILITY.json and EVIDENCE.md. No schedule or release version is implied.

## Universal entry and exit gates

Before implementation: accepted intent; explicit scope/non-goals; Given/When/Then scenarios; reviewed design/data impacts; traceability rows; fixture/test plan; dependencies passed. Before completion: tests cover positive and negative behavior, existing relevant regressions pass, documentation/manual instructions match shipped behavior, and evidence identifies the exact commit/device/toolchain. Product disagreements or material architecture/data-loss decisions return to specification review.

The owner superseded the separate-branch/merge-per-milestone proposal: all EP0–EP6 implementation remains on `docs/easy-pro-intent-specs` and PR #3. Use bounded commits for specification, failing tests, implementation, and evidence within this branch. Do not merge an intermediate milestone to main. Keep the PR draft until full implementation and applicable release evidence are ready. Human novice/native review remains a release gate, not fabricated evidence.

## EP0 — Revised product and intent baseline

**Intent:** I-01 through I-06. **Depends on:** none.

Specification deliverables: the five documents in this directory; D-01–D-08 decision set; three journeys; lifecycle/data contracts; source audit; traceability/scenarios; full milestone and validation sequence.

Implementation: none. No native/CI/prototype changes in this PR.

Exit: owner agrees on app form and decisions; unresolved interpretations are recorded and resolved or explicitly deferred outside scope; cross-references and scenario coverage validate. Record approval revision and evidence. Current owner feedback validates perceived ease of the original prototype, not the expanded journeys.

## EP1 — Specification validation and expanded-flow review

**Intent:** I-06, with I-01/I-02/I-03 usability. **Depends on:** EP0.

Spec first: define the machine-readable traceability schema, allowed statuses, approval/implementation/evidence rules, requirement/test identifiers, failure diagnostics and valid/invalid fixtures. Specify CI job inputs, no-network local operation and exact failure conditions. Prepare wireframes/prototype specifications for three paths, generic/unknown starts, conflict resolution, timing terminology and recovery. Each owner-visible control must have a behavior contract.

Implementation after agreement: minimal spec validator and its tests; a fast spec CI check; reviewable expanded prototype. This is tooling/design work, not a replacement native exercise engine. Preserve source/commit evidence for prototype changes.

Required validation: prove duplicate/orphan IDs, missing scenarios, broken links, cycles, fake completion and missing acceptance fail; prove proposed records are allowed in review mode but rejected as implemented/complete. Owner walks all three flows; run novice task sessions or retain an explicit unmet usability gate. No feature readiness is claimed from mock interaction.

Exit: executable spec checks pass, negative fixtures fail as expected, final screen form accepted, native implementation references still empty. Novice evidence remains tracked through EP6 if not yet complete; no fabrication or silent waiver.

## EP2 — Shared lifecycle, schema and experience foundation

**Intent:** I-04/I-05/I-06. **Depends on:** EP1.

Spec first: an architecture decision record chooses canonical storage for freestyle exercise intervals and generic timed styles. Prefer existing WorkoutSession/WorkoutSessionExercise for freestyle and TrackedActivitySession for standalone timers with additive category metadata; justify any alternate against identity, migration, backup, existing Health export and program behavior. Define idempotent command and ownership contracts, injected clock API, unsupported-category behavior, install/restore detection, mode application and cross-device preference policy. Pin concrete clock-discontinuity/recovery thresholds before their tests. Inventory every existing destination and provide its Easy/Pro route. No schema change may precede the migration spec.

Implementation after agreement: experience store/policy; additive schema/services and migrations as needed; canonical lifecycle/interval commands; conflict policy; safe route/presentation adapters; shared clock seams. No second logging engine or speculative app-wide refactor.

Required tests: mode/restore matrix; zero-history upgrade; null metric round trips; legacy/new backup fixtures; raw unknown categories; command repeat/race/failure invariants; controlled-clock pause/recovery; full relevant existing domain suites.

Exit: schema/backup compatibility demonstrated, no data loss or invalid-category relabeling, existing Pro behavior preserved, new command APIs documented and traceable.

## EP3 — Just start a timer

**Intent:** I-03/I-04. **Depends on:** EP2.

Spec first: stable preset catalog and labels; recent/favorite ordering; quick-start tap path; timer/pause/resume/finish/abandon screens; background/video independence; persistence failure and empty-summary cases; local-only/Health-unavailable behavior. Review Health mappings separately before exposing export for new categories.

Implementation: nine style presets with four default shortcuts; generic count-up tracking; history and recovery through canonical services. Use the same capability from Pro. No video embedding or playback integration.

Required tests: all presets have valid identity; repeat start/finish idempotency; fake-clock timing; denied sensor/Health permission; offline use; local correction/export state; terminate/relaunch and switching to video on device.

Exit: choose a style and record a valid activity without routine/numeric setup; no duplicate record, fabricated metrics, audio disruption or walking fallback. Document any new-category Health export as unavailable until its explicit mapping passes.

## EP4 — Gym freestyle and exercise transitions

**Intent:** I-02/I-04. **Depends on:** EP2, EP3.

Spec first: recent/favorite/search/unknown exercise flows; optional sets; duration-only semantics; finish exercise versus finish workout; between-exercise state; canceled picker; repeating the same machine; optional rename; rest ownership; mixed timed and set-based entries within a single freestyle workout. Define session/exercise/rest aggregation with worked examples.

Implementation: exercise picker direct starts; session-local unknown exercise; active exercise timing; optional existing set editor; finish/next workflow; correction and summary. Preserve existing logging/undo and snapshotted catalog identity.

Required tests: duration-only entries never gain sets; known/unknown/repeated exercises retain distinct IDs; cancel-next leaves no partial entry; retry/failure never loses completed work; new exercise cannot inherit previous rest; mixed entries produce nonduplicated totals; process interruption at each transition.

Exit: an owner can start one machine, record optional details, complete it, start another and finish a single truthful workout. Known recent next exercise within two taps from finished-exercise state, excluding conflict handling/search typing.

## EP5 — Easy guided experience and daily use

**Intent:** I-01/I-05. **Depends on:** EP3, EP4.

Spec first: integrated Today/Workouts/Progress navigation; resume priority and multi-active chooser; curated ready-to-use content; instructions; program/guided entry; warm-up/main/cool-down; repeat/schedule paths; empty/low-data progress; full destination matrix. Review English/Spanish beginner terminology and exercise content before shipping.

Implementation: guided presentation over shared services; bounded quick starts; simple progress/history; reachable detail/editor/export/settings surfaces; optional scheduling/program entry; corresponding Pro entry conveniences. Do not rewrite program progression algorithms.

Required tests: existing guided and program provenance/regressions; starter reference failure; zero/partial history; record visibility across mode round trips; all destination routes; access to corrections/export; iPhone/iPad and large text.

Exit: all three forms coexist without a crowded Home or lost Pro capability; returning users can resume/repeat; duration-only quick starts do not alter program adherence or strength records.

## EP6 — System integration, usability and release evidence

**Intent:** I-04/I-05/I-06. **Depends on:** EP5.

Spec first: platform mapping matrix; supported Watch/widget/Live Activity/Shortcut actions; stale/conflicting route outcomes; backup/downgrade policy; release candidate regression matrix; manual device checklist; usable/blocked/unsupported state disclosures. Establish change-scoped required CI jobs without modifying repository protections through an agent workaround.

Implementation: validated new-category Health mappings where faithful; system-surface integration; accessibility/localization fixes; bounded automated UI gates, release docs and diagnostics. Preserve existing useful tests; new smoke selections complement them.

Required evidence: specification validator and negative fixtures; domain/integration suites; iOS/iPadOS/watchOS builds as affected; critical UI flows in UITestHost; real-device video/lock/recovery/audio behavior; unit locale and localization checks; migrations/backup/restore; manual VoiceOver/large text; five-novice task results including all three paths.

Exit: at least 4 of 5 novices independently start/finish each applicable path and correctly explain saved/unknown/skipped values; measured quick-start targets reviewed. Any data-integrity misunderstanding blocks release until resolved and retested. All critical automated and manual evidence refers to the release candidate commit. An explicitly approved scope change must update specs/tests/status before release; missing evidence is not a pass.

## Milestone evidence record

For each milestone retain: milestone ID; specification revision; decision/approval reference; requirement/scenario IDs; code commit; implementation/test paths and actual test identifiers; command/job; toolchain/device/runtime; result and artifact; manual observer/date/outcome; unresolved items; exit reviewer. Mark not_run, blocked, failed, passed or waived explicitly. A waiver requires a rationale and owner acceptance and cannot disguise an unmet data-integrity gate.
