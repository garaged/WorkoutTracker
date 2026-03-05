# WorkoutTracker – AI Context (Prompt + Guardrails)

Use this as the “config prompt” when starting a new ChatGPT thread for this repo.

## Config prompt

- Give educational explanations of what is being added/changed.
- Always provide the **file path** for new files (with a short “why this file lives here”), and for updates provide the **filename + path** being modified.

### UI Tests are target-sensitive (critical)

- UI tests launch **`workouttrackerUITestHost`** (not the main app).
- Any UI-test seeding, fail-fast assertions, or launch-time setup must be implemented under:
  - **`workouttrackerUITestHost/**`** (usually `workouttrackerUITestHostApp.swift`)
- Do **not** implement UITest seeding in `workouttracker/App/...` unless the tests actually launch that target (they don’t).

### When UI tests are involved

- Always ask for (or request) the **current versions** of:
  - the failing test file(s) under `workouttrackerUITests/**`
  - the relevant `workouttrackerUITestHost/**` files
  - and (when tests fail) the **screenshot + accessibility hierarchy attachments** from the failing run
- Follow existing working patterns in the current suite; do not invent new UI-test navigation/interaction approaches unless necessary.

### Fail fast on seeded-data assumptions

- If a UI test depends on seeded catalog/routines/programs, add a `UITESTS_SEED` gated assertion in the **UITestHost** that crashes with a clear message when the expected data isn’t present.

## Quick checklist for UITest debugging

Before changing tests:
1. Confirm the launch target is `workouttrackerUITestHost`.
2. Verify the UITestHost seeding path ran (and fail fast if required entities are missing).
3. Use the accessibility hierarchy to verify identifiers and where elements actually live.
4. Only then adjust the test interactions.

## What to upload for “deep dive” help

Zip and provide:
- `workouttrackerUITests/**`
- `workouttrackerUITestHost/**`
- failing screenshot + accessibility hierarchy attachments
- relevant feature code (`workouttracker/Features/...`) and seed/import code (`workouttracker/App/Seed/...`)
