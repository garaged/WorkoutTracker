# Specification and code validation contract

Status: accepted validation contract. Implementation and executed evidence are tracked in EVIDENCE.md; planned validation is never reported as passed.

## Development loop

1. Capture user intent and a concrete behavior in the milestone specification.
2. Assign stable requirement/scenario IDs and obtain required product/architecture agreement.
3. Write the smallest meaningful failing test for that behavior; retain the command/result on the exact commit. Do not invent "red" evidence or deliberately break unrelated behavior to manufacture it.
4. Implement through shared services; make the behavior pass, including specified failures/recovery.
5. Run targeted regressions, then the milestone gates and update traceability/manual instructions.
6. Review evidence and spec/code drift before merging the coherent milestone PR.

This is intent → accepted spec → behavioral test → code → evidence. Markdown alone is not SDD if it no longer matches implementation.

## Specification validator (EP1 implementation contract)

TRACEABILITY.json is currently a review manifest. EP1 must formalize its schema and validate it without network access. Proposed commands such as `make spec-check` and `make spec-test` are interfaces to implement and document, **not existing repository commands**. A small standard-library validator is preferred over adopting a framework merely to store requirements. Existing OpenSpec is not present in the inspected tree; do not claim it is installed or required. If selected later, migration must preserve these IDs and approval/evidence semantics.

Required checks:
- Manifest version, field types/enums, required fields and stable ID formats.
- Unique IDs across the appropriate namespaces; all intent/requirement/scenario/milestone references resolve; no duplicate ownership or missing scenario coverage.
- Milestone graph has no cycles or unknown dependencies.
- Every scenario has meaningful nonempty Given/When/Then, a requirement link and a planned validation layer.
- All requirement IDs exist in the normative BEHAVIOR document; local Markdown links and cited local artifacts resolve.
- Definition-of-ready mode: implemented requirements must reference an approved specification revision and actual implementation/test references; draft/proposed baseline is legal only in review mode.
- Definition-of-done mode: completed milestones have passing applicable scenarios, current implementation/test references and exact-commit evidence. Not_run/blocked/failed/waived is not automatically passed.
- Tests and referenced source files exist; the named test identifiers can be found or enumerated using the appropriate runner. A fake path or a planned test name is never passing traceability.
- Behavioral changes must identify affected requirement/scenario IDs in the PR. Runtime gate changes require updated validation specification; no disabling required checks merely to make a PR green.

Validator negative fixtures: duplicate requirement ID; missing intent; unknown milestone; dependency cycle; missing scenario; blank assertion; orphan scenario; broken local link; nonexistent test path; implemented-but-unapproved requirement; completed-with-pending-evidence; evidence for a different commit. At least one valid proposed manifest and one valid completed fixture must pass. Tests must assert diagnostic IDs/locations, not brittle full message strings.

The validator checks structural integrity; semantic intent correctness still requires review. JSON passing validation is not proof that a UI is understandable or a migration is safe.

## Planned automated layers

| Layer | What it must prove | Important failure cases |
|---|---|---|
| Pure policy/unit | mode selection, quick starts, category mapping, metrics, state transitions | unknown categories, zero-history upgrade, unsupported routes, invalid commands |
| Deterministic timing | interval accounting with injected clocks | pause/resume, background, backward time, repeated finish, discontinuity |
| Property/model-based | invariants over generated action sequences | finish twice, pause twice, stale revision, interrupted commit, cancel/start races |
| Persistence integration | real temporary SwiftData stores plus controlled faults | reopen after crash, migration, snapshots, save failure and retry |
| Backup/export contracts | legacy fixture and new record round trips | unknown enums, nil metrics, deleted catalog, incompatible formats |
| Health/system integration | faithful mapping and identity across surfaces | denial, unavailable mapping, failed/retried export, stale widget/Watch actions |
| UI smoke | actual end-user completion through correct host | direct start, optional metrics, next/cancel, timer, recovery, mode switch |
| Platform build | iPhone/iPad/Watch targets remain valid | target membership, app/host differences, availability gates |
| Manual device/usability | behaviors automation cannot establish adequately | external video/audio, lock/relaunch, VoiceOver, novice comprehension |

Use seeded deterministic fixtures, isolated temporary stores and controllable clocks. Avoid real sleeps, public APIs, accounts or real health data in tests. Assert canonical record identity/count, state, measured totals and visible outcomes. Introduce a property-testing library only if needed; generated Swift sequences with deterministic seeds may suffice.

Worked timing oracle: run 60 seconds, pause 30, resume for 20, finish twice. Active duration must equal 80 seconds; pause duration must not be added; only one completion/history/export intent may exist. A 10-second rest within a 60-second exercise remains part of those 60 seconds, not 70. Between exercises, workout duration may increase while both exercise durations remain fixed.

Worked honesty oracle: start unnamed exercise, run 45 seconds, finish without sets. One completed exercise with 45 seconds; zero completed sets; nil reps/load; no new volume/PR; no inferred program completion. Renaming later retains the ID and totals.

## CI evolution

Current `.github/workflows/ios.yml` runs unit tests on PR/main and UI tests through an optional manual dispatch. That is existing behavior, not a sufficient release gate for these new paths. Keep working checks while adding bounded checks after EP0 approval.

Proposed gate groups:
1. Every PR: fast spec integrity and validator negative fixtures; diff-to-requirement declaration; approved-state checks appropriate to the PR type.
2. Native behavior changes: affected unit/integration/property suites plus relevant existing regressions and target builds. New numeric behavior includes locale/unit tests.
3. Session/navigation changes: a bounded required UI smoke subset using workouttrackerUITestHost. Do not silently skip because a workflow input is absent. Failures retain screenshots, accessibility hierarchy and xcresult.
4. Milestone/release: all applicable native suites, migration/backup fixtures and platform build matrix; broader UI scenarios and explicit manual evidence.

At EP1/EP6 specify actual job names, simulator/runtime availability and measured time budgets from the current environment. Do not hardcode a guessed new Xcode/runtime pair in this proposal. Distinguish tests that never started due to infrastructure from code failures; neither is a pass. Retries for infrastructure are recorded; a flaky critical scenario blocks completion until understood. Retain useful success summaries as well as failure artifacts.

Required CI jobs are a workflow requirement; branch protection/ruleset administration remains an owner action if necessary. Never bypass unavailable permissions. This document does not claim any required-job setting is already installed.

## UITestHost boundary

Before implementing or changing UI tests, request the current relevant test files and `workouttrackerUITestHost/**` files. When a test fails, request screenshot and accessibility hierarchy attachments. Inspect and reuse the current suite's navigation, launch arguments and identifiers.

All new seed setup, seed ownership, launch-time assertions and deterministic state injection MUST be in `workouttrackerUITestHost/**`, normally the host app file or its existing seed helpers. A `UITESTS_SEED`-gated assertion must fail clearly when required catalog/routine/program/generic records are absent. Do not put this setup under `workouttracker/App/**`; the UI tests launch the host target, not the main application. Code shared intentionally with the app must not accidentally activate test-only behavior in production.

UI test implementation is deferred, so no current UI-test files/attachments are needed to agree on this proposal. They must be requested at that implementation step rather than blocking specification work now.

## Manual acceptance scripts

Run on a candidate build, record device/OS/build commit and actual outcome. The browser prototype can support design sessions but cannot establish native correctness.

### A. Guided

Choose prepared workout; read instructions; change an actual repetition count; complete a set; extend rest; skip one exercise; leave/relaunch/resume; finish. Verify confirmed/skipped counts, segment ordering and program provenance when applicable. Expected: no target converted to an unconfirmed actual.

### B. Gym freestyle

Start recent machine; record one optional set; finish exercise; open Next and cancel; reopen and start unnamed exercise; run briefly; finish it without sets; rename; repeat the first machine; finish workout. Expected: one workout, three distinct exercise entries, no phantom entry from cancel, truthful duration and only the set actually logged. Repeat by interrupting save/transition in the fault-injection host.

### C. Video/style timer

Choose a style; start; switch to a video app; lock/unlock; return; pause/resume; finish. Expected: active time excludes pause, includes background, playback has not been taken over, no required URL/catalog/location permission, one local record with no fabricated energy or distance. Repeat for an unmapped Health category and denied permission.

### D. Conflict and identity

Start on phone, issue a competing start from Watch/Shortcut, cancel conflict, resume the original, then explicitly finish-and-start. Expected: original retained, no duplicate running quick start, failed finish leaves new session uncreated. Exercise stale links and legacy multiple-active data separately.

### E. Compatibility

Upgrade seeded existing and zero-history installations; restore legacy backup; create new styles; export/restore; switch modes; inspect advanced routines and program results. Expected: existing users retain Pro, IDs and unknown fields survive supported round trips, new categories are never walking by fallback, explicit unsupported-format handling on incompatible imports.

### F. Accessibility and usability

English/Spanish, iPhone/iPad, largest supported text, VoiceOver and reduced motion. Ask novices to choose each path, correct a result, pause/resume and find history without coaching. Do not require physical exercise; simulate actions. Record times, taps, assistance and misunderstood saved data. Target ≥4/5 unaided completion per applicable path; investigate every false-data interpretation. Owner feedback and participant evidence have different labels.

## Evidence and present status

This PR contains only specifications. Any structural checks performed now are document checks, not the future installed validator or native tests. No native code is changed; native tests, builds and UI tests are not run. Existing repository CI may trigger on the documentation PR; report its actual state separately without dispatching a full suite just to imply feature validation.

On implementation approval, robust tests/validation are part of the requested work; use targeted gates and persist their evidence. Do not ask for repeated blanket permission where the session already authorizes required validation. Any still-applicable repository restriction must be reconciled explicitly, not silently ignored.
