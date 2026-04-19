# AGENTS.md — workouttrackerUITestHost

This target owns UI-test seeding and launch-time assertions.

## Responsibilities
- Add UI-test seeding here when tests depend on seeded data.
- Add fail-fast assertions here when seeded assumptions must be validated at launch.
- Keep this target aligned with the patterns already used by the existing UI test suite.

## Critical rules
- Do **not** move UI-test seeding into the main app target unless the tests actually launch that target.
- If a UI test depends on seeded routines, programs, assignments, or starter-pack data, validate those assumptions here under a `UITESTS_SEED` gate.
- Crash early with a clear, actionable message when required seeded data is missing.

## When touching UI-test setup
Inspect first:
- the current failing UI test file(s)
- the current `workouttrackerUITestHostApp.swift`
- any screenshot + accessibility hierarchy artifacts from the failing run

## Implementation style
- Reuse current working seeding and launch-argument patterns.
- Keep setup deterministic and easy to debug.
- Prefer explicit assertions over hidden fallback behavior.
