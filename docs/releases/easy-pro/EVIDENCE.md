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
