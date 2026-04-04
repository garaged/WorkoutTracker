# AGENTS.md — WorkoutTracker (Codex guardrails)

Read **docs/AI_CONTEXT.md** first. Treat it as the authoritative project context and guardrails.

## Working style
- Provide educational explanations of what is being added/changed.
- For new files: include full **file path** + short reason it lives there.
- For edits: include **filename + path** being modified.

## UI tests are target-sensitive (critical)
- UI tests launch **workouttrackerUITestHost** (not the main app).
- Any UI-test seeding, fail-fast assertions, or launch-time setup must be implemented under:
  - **workouttrackerUITestHost/** (usually workouttrackerUITestHostApp.swift)
- Do NOT implement UITest seeding in workouttracker/App/... unless tests actually launch that target.

## When UI tests are involved
Before proposing changes, request current versions of:
- failing test file(s) under workouttrackerUITests/**
- relevant workouttrackerUITestHost/** files
- failing screenshot + accessibility hierarchy attachments
Follow existing suite patterns; don’t invent new navigation unless necessary.

## Seeded-data assumptions must fail fast
If a UI test depends on seeded catalog/routines/programs, add a UITESTS_SEED-gated assertion in the UITestHost that crashes with a clear message when expected data isn’t present.
