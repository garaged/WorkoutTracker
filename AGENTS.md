# AGENTS.md — WorkoutTracker

Read **`docs/AI_CONTEXT.md`** first. Treat it as the authoritative project context and guardrails.

## Purpose
This file contains durable repo-level instructions for Codex and other coding agents. Keep feature-release planning in release docs under `docs/releases/...`, not here.

## Working style
- Provide educational explanations of what is being added or changed.
- For new files: include the full **file path** and a short reason the file lives there.
- For edits: include the **filename + path** being modified.
- Prefer small, reviewable diffs over broad speculative refactors.
- Preserve existing behavior unless the task explicitly changes it.

## Architecture
- Follow the existing **feature-first UI + shared domain models** approach.
- Domain models belong under `workouttracker/Domain/Models/`.
- Service logic belongs under `workouttracker/Services/`.
- Feature screens belong under `workouttracker/Features/<FeatureName>/`.
- New Programs screens belong under `workouttracker/Features/Programs/`.
- Keep domain/runtime state separate from view-only state.

## Safety and regression control
- Be careful when modifying existing files; do not remove meaningful behavior accidentally.
- If a change risks regression or needs follow-up cleanup, state that clearly and add or update tests where appropriate.
- Reuse existing navigation and interaction patterns before inventing new ones.
- Avoid coupling new feature logic directly into unrelated views when a service or domain model is a better home.

## UI tests are target-sensitive (critical)
- UI tests launch **`workouttrackerUITestHost`** — not the main app target.
- Any UI-test seeding, fail-fast assertions, or launch-time setup must be implemented under:
  - **`workouttrackerUITestHost/`** (usually `workouttrackerUITestHostApp.swift`)
- Do **not** implement UITest seeding in `workouttracker/App/...` unless tests actually launch that target.

## When UI tests are involved
Before proposing changes, inspect the current versions of:
- failing test file(s) under `workouttrackerUITests/**`
- relevant files under `workouttrackerUITestHost/**`
- failing screenshot + accessibility hierarchy attachments, when available

Then:
- follow existing suite patterns
- do not invent new navigation or interaction approaches unless necessary
- keep selectors and assertions aligned with existing working tests

## Seeded-data assumptions must fail fast
If a UI test depends on seeded catalog data, routines, programs, or assignments:
- add a `UITESTS_SEED`-gated assertion in the UITestHost
- fail with a clear message when expected data is missing
- prefer explicit seeded-data validation over hidden test flakiness

## Programs / progression / coaching workflow
For tasks involving **programs**, **progression**, **coaching**, or **v2.3.0**:
1. Read `docs/releases/v2.3.0-programs/EXECUTION_PLAN.md`
2. Read the specific PR doc before editing
3. Implement **only** the requested PR scope unless the prompt explicitly expands it

Related docs:
- `docs/releases/v2.3.0-programs/FILE_MAP.md`
- `docs/releases/v2.3.0-programs/TESTING.md`

## Validation workflow
- Do not run tests, builds, lint, or long verification commands unless I explicitly ask.
- After implementation, stop and provide:
  - a concise summary of changes
  - the exact files changed and why
  - a short manual validation checklist I can run myself
  - any likely compile or integration risk areas to inspect manually
- Prefer code inspection and repo-grounded reasoning over expensive command execution.
- If a command seems necessary for confidence, propose it but do not run it without permission.
