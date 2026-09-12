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
