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

The next implementation adds the interval reducer, mode-preference value policy, stable style catalog and selection/conflict policy with 17 total Swift fixtures. Green evidence is pending the next hosted run. No shipping UI or persistence adapter is wired by this policy slice.
