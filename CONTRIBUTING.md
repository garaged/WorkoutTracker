# Contributing to Workout Tracker

Thanks for considering contributing. This project is intentionally lightweight and “on-device first,” so changes should stay simple, fast, and privacy-friendly.

## Quick start (dev setup)

### Requirements
- Xcode 16+ (or the version specified in the project)
- iOS target: use whatever the Xcode project is currently set to

### Build & run
1. Open `workouttracker.xcodeproj`
2. Select the `workouttracker` scheme
3. Run on a simulator or device

### Tests
- Run all tests: `⌘U`
- If you add/modify behavior, include tests when it makes sense:
  - Unit tests: `workouttrackerTests`
  - UI tests: `workouttrackerUITests` (and `workouttrackerUITestHost` as needed)

## How to contribute

### 1) Create an issue first (recommended)
For anything non-trivial (new screens, model changes, migrations, data export format changes), open an issue describing:
- What problem it solves
- The proposed approach
- Any UI screenshots/mockups (even rough)

Small fixes (typos, tiny UI tweaks) can go straight to a PR.

### 2) Branch naming
Use short, descriptive names:
- `feature/<short-name>`
- `fix/<short-name>`
- `chore/<short-name>`

### 3) Pull request expectations
A good PR includes:
- A clear description of the change
- Screenshots for UI changes (before/after if helpful)
- Notes about data model changes (SwiftData) and migration impact
- Updated tests if behavior changed
- No new warnings

Keep PRs focused: one theme per PR.

## Code style & project conventions

### SwiftUI
- Prefer small views and extract subviews when a screen grows
- Keep view bodies readable (avoid giant nested closures)
- Avoid business logic inside views; push it into small helpers/services

### SwiftData / persistence
- Keep fetches deterministic (explicit sorts and predicates)
- Prefer additive model changes
- If you change models in a way that impacts existing data, document the migration approach in the PR description

### General style
- Clear naming over clever abstractions
- Keep files and folders aligned with the existing layout:
  - UI: `workouttracker/Features/*`
  - Models: `workouttracker/Domain/Models/*`

## Privacy principles (important)

This is a fitness app. Treat privacy as a feature.

Contributions must not:
- Add user tracking by default
- Send workout data off-device without a clear opt-in flow
- Introduce analytics/ads/sync without updating privacy docs

If you add anything network-related (analytics, crash reporting, sync, etc.), you must:
1. Update `PRIVACY.md`
2. Mention the change prominently in the PR
3. Consider the App Store privacy disclosures impact

## Reporting bugs
When filing an issue, include:
- Device + iOS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots/screen recordings if relevant
- Any crash logs if available

## License
By contributing, you agree that your contributions are licensed under the Apache License 2.0 (see `LICENSE`).
