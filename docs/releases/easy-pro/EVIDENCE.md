# Execution evidence

## Environment and limits

Native Xcode and Swift tools are unavailable in the current Linux workspace. Python specification tests can run locally. Native evidence must come from repository CI or owner-provided Xcode/device runs. Missing platform access is not a pass.

## EP0

Product revision accepted; same-branch workflow recorded in APPROVAL.md. Existing structural document inspection passed on the baseline. Native and novice acceptance remain pending.

## EP1

Specification validator: implementation in progress. Test results will identify commands and source revisions below.

### Executed specification fixtures

Red source commit: `eefba936bebe89c23d2ddc70c94726bc5da3f39d`. `python -m unittest discover -s scripts/tests -q`: 27 tests, 24 expected behavioral failures against the empty validator (not only an import failure).

After implementation: 30 tests passed; `python scripts/spec_check.py --mode ready` passed with zero diagnostics. Tests include valid proposed/accepted/completed fixtures and failure cases for IDs, links, orphan definitions, cycles, invalid field types/statuses, missing test symbols, unapproved implementation, and stale/absent completion evidence. The deterministic fixture suite uses temporary directories, no network and no application data.

The Specification quality workflow now runs these gates on PRs. This is evidence for the validator slice, not completion of all EP1 user-flow validation or any native milestone. Native release and novice scenarios remain not_run.

### Swift timing red evidence

Source head `73953a70fa8dadc6f7ce50000099494769b527a9`; tested PR merge ref `ca18bc7abce9f991d3b2d2f3f811998fa049e546`. [Specification quality run 34357918897](https://github.com/garaged/WorkoutTracker/actions/runs/34357918897), Swift policy job 102487196379: compile succeeded; 10 timing tests executed with 56 expected assertions failing against the stub. This is observed behavioral red evidence, not a compiler/import failure.

The implementation adds the interval reducer, mode-preference value policy, stable style catalog and selection/conflict policy with 17 total Swift fixtures. No shipping UI or persistence adapter is wired by this policy slice.

### Swift policy green and iOS infrastructure failure

Source head `17d2db8720dfd7aff875e5995a321fa659dece25`; tested PR merge ref `cc6c872115554da5f79e277b390afe9eadbe9079`. [Specification quality run 34358259633](https://github.com/garaged/WorkoutTracker/actions/runs/34358259633) passed both the specification integrity/negative fixtures and Swift quick-start policy jobs. This validates the isolated policies, not persistence or native UI integration.

[iOS run 34358259656](https://github.com/garaged/WorkoutTracker/actions/runs/34358259656), job 102489539997, failed before tests: the restored WatchSimulator SwiftShims module referenced an SDK module map whose mtime changed between runner images. The workflow cache namespace now includes runner image version, architecture, and selected Xcode fingerprint; its restore prefix has the same boundary. No test gate is skipped. A subsequent iOS run is required to establish app build/test evidence.

### Versioned payload red evidence

Source head `3b1e5e8126375d8bf3fe2c4fe46145711f580806`; tested merge ref begins `f99b46a`. [Specification quality run 34687587291](https://github.com/garaged/WorkoutTracker/actions/runs/34687587291), Swift job 103537179819: 23 tests executed, 9 expected assertions failed across 3 new payload tests; the previous 17 policy tests remained green. The failures demonstrate missing version, empty-style, and timing-state integrity validation. The new payload implementation is followed by separate canonical backup tests; neither slice is shipping UI evidence.

[iOS run 34687587306](https://github.com/garaged/WorkoutTracker/actions/runs/34687587306), job 103537223640, built successfully with the new cache boundary and executed 330 unit tests: only the same 9 expected payload assertions failed. The cache issue is resolved on this run. UI tests were not run. Earlier cache-fix run 34687519102 was cancelled by the subsequent branch push and provides no native pass evidence.

### Payload green and backup red evidence

Source head `30b3cc88d4dcaefc423b7a92fd6ed836ba344b6f`; tested merge ref begins `58a2b2a`. [Specification quality run 34688040628](https://github.com/garaged/WorkoutTracker/actions/runs/34688040628) passed, including all 23 portable Swift fixtures. [iOS run 34688040620](https://github.com/garaged/WorkoutTracker/actions/runs/34688040620), job 103538382264, built and executed 334 tests with 8 expected backup assertions failing: omitted payload bytes, lost unknown raw kind, absent schema bump, and malformed outer encoding accepted. The payload validation tests passed in the app target too. Four new backup tests include a passing legacy version-5 fixture. The next change implements the typed backup contract and adds neutral-kind/Health protection tests; that next slice requires its own native result.

### Backup green and neutral-kind red evidence

Source head `1280d1331fe2f09871a7fec81c1693607a3b988b`. [Specification quality run 34688424140](https://github.com/garaged/WorkoutTracker/actions/runs/34688424140) passed. [iOS run 34688424145](https://github.com/garaged/WorkoutTracker/actions/runs/34688424145), job 103539379010, built and executed 336 tests. All four new schema-6, legacy, and malformed-backup tests passed. Six expected assertions failed in the two new neutral-kind tests: an unknown stored raw kind still resolved to walking capabilities and produced a Health walking request. The next change adds the neutral generic kind, keeps it out of the specialized start picker, rejects unsupported Watch start values, and fails Health mapping explicitly. UI tests were not run.

### Neutral-kind integration compile correction

Source head `9f8c11a38c254809c86fd08ec2a1022bb6a4eb05`. [iOS run 34703383131](https://github.com/garaged/WorkoutTracker/actions/runs/34703383131), job 103578998252, stopped before tests because the new generic case was missing from the Progress dashboard tint switch. This was a source failure, not recorder red evidence. The correction adds the neutral tint; no check is bypassed.

### Neutral-kind green and canonical recorder red evidence

Source head `01e12b83e12b1ecfbedb520bfb5ef548f32adfd6`. [Specification quality run 34703583241](https://github.com/garaged/WorkoutTracker/actions/runs/34703583241) passed. [iOS run 34703583242](https://github.com/garaged/WorkoutTracker/actions/runs/34703583242), job 103579505085, built and executed 342 tests. The neutral-kind, unknown raw identity, Health rejection, and previous backup/payload tests passed. Six new recorder fixtures produced 15 expected failures against the deliberate stub: no canonical insertion, no conflict detection, no lifecycle persistence/reopen result, and no injected-save rollback. The next change implements those operations; it requires a separate green run. UI tests were not run.

### Recorder rollback correction

Source head `543fbcc9ac38113d86c55d33135b4f05f258e7b4`. [Specification quality run 34704124280](https://github.com/garaged/WorkoutTracker/actions/runs/34704124280) passed. [iOS run 34704124261](https://github.com/garaged/WorkoutTracker/actions/runs/34704124261), job 103580966678, built and executed 342 tests: 339 passed. The remaining three assertions showed that SwiftData rollback protected the store after an injected finish-save failure but left the caller's referenced model with proposed values. The correction restores the captured committed fields before rollback so both the store and UI-visible instance remain committed. A subsequent run is required.

### Canonical recorder green evidence

Source head `a7cb234da36b7380a642258c1c4a8556fe5b6678`. [Specification quality run 34704524467](https://github.com/garaged/WorkoutTracker/actions/runs/34704524467) passed. [iOS run 34704524465](https://github.com/garaged/WorkoutTracker/actions/runs/34704524465), job 103582059294, built and executed all 342 tests with zero failures. This validates canonical quick-start identity, one-record persistence/reopen behavior, active-session conflicts, 80-second pause/resume timing, dirty-context isolation, failed-start cleanup, and failed-finish restoration. It does not validate UI, Watch command ownership, or manual background behavior.

### Experience preference store red evidence

Source head `7fccdc7a24fb3194d251e0828745287760e88e09`. [iOS run 34705044349](https://github.com/garaged/WorkoutTracker/actions/runs/34705044349), job 103583472751, built and executed 346 tests. The four new preference-store tests ran against the deliberate no-op store: the explicit new/existing-install bootstrap test passed, while five expected assertions failed across saved-choice relaunch, pending active-session changes, idle application, and corrupt-snapshot recovery. All prior native tests passed. This is behavioral red evidence for versioned mode persistence; it is not Easy/Pro UI evidence.

### Experience preference store green evidence

Source head `2751a95cc4802404096b45af679fe9ce598b5b8b`. [Specification quality run 34705396557](https://github.com/garaged/WorkoutTracker/actions/runs/34705396557) passed. [iOS run 34705396540](https://github.com/garaged/WorkoutTracker/actions/runs/34705396540), job 103584425973, built and executed all 346 tests with zero failures. This validates new-install Easy bootstrap, explicit upgrade evidence selecting Pro, saved-choice precedence, persisted deferred changes during an active session, idle application, and stable recovery from corrupt preference data. It does not yet validate the mode picker or Easy app shell.

### Production quick-start clock red evidence

Source head `238c5f3a7f097ab70938b581a53fe8b981ceb725`. [Specification quality run 34705846669](https://github.com/garaged/WorkoutTracker/actions/runs/34705846669) passed. [iOS run 34705846673](https://github.com/garaged/WorkoutTracker/actions/runs/34705846673), job 103585617341, built and executed 350 tests. Nine expected assertions failed against the deliberate fixed-value clock stub: injected wall/continuous values were ignored, the process epoch changed between samples, production wall time was zero, and a 37-second reducer interval recorded zero. The impossible-negative clamp test and all prior tests passed. This is behavioral red evidence for the production clock seam, not background/device evidence.


### Production quick-start clock green evidence

Source head `d7051baa003053b1601381b704be52e6446ebb75`. [Specification quality run 34706154341](https://github.com/garaged/WorkoutTracker/actions/runs/34706154341) passed. [iOS run 34706154337](https://github.com/garaged/WorkoutTracker/actions/runs/34706154337), job 103586454807, built and executed all 350 tests with zero failures. The four adapter tests validate injected wall/continuous samples, precise duration conversion, a stable process epoch, nonnegative elapsed values, and a 37-second interval derived by the reducer rather than display ticks. Real-device sleep/background and cross-launch review remain manual EP3/EP6 evidence.


### Explicit clock-recovery red evidence

Source head `9a2a37434088deab3cd61bbdb1bd11a26e6ed8f4`. [Specification quality run 34706655821](https://github.com/garaged/WorkoutTracker/actions/runs/34706655821), Swift job 103587810878, compiled 26 portable policy tests and produced seven expected failure assertions across the three new recovery tests. [iOS run 34706655828](https://github.com/garaged/WorkoutTracker/actions/runs/34706655828), job 103587810932, built and executed 355 tests with 11 failure assertions confined to the five new recovery tests: the no-op stubs did not pause or complete timing, did not reject invalid revision/state, did not persist canonical lifecycle changes, and did not exercise save-failure rollback. XCTest classified the follow-on invalid transition in the stub pause/resume scenario as one unexpected test error; it is a direct consequence of the deliberate no-op. The post-failure xcresult upload step also failed, but decoded job logs provide the assertion evidence. All prior tests passed.


### Explicit clock-recovery green evidence

Source head `97d834b561fbaa29adc2eef293b377200b55fd95`. [Specification quality run 34729798436](https://github.com/garaged/WorkoutTracker/actions/runs/34729798436) passed, including all 26 portable policy tests. [iOS run 34729798428](https://github.com/garaged/WorkoutTracker/actions/runs/34729798428), job 103650361655, built and executed all 355 tests with zero failures. This validates explicit pause-at-last-saved-time and finish-at-last-saved-time recovery, idempotent recovery command identity, revision/state rejection, canonical lifecycle persistence, and rollback after injected recovery-save failure. The user-facing recovery choice remains part of the timer UI slice.
