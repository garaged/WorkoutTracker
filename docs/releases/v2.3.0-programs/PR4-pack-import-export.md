# PR4 — Program pack import/export

## Goal
Allow bundled program packs and user-shareable JSON program packs with explicit schema versioning and validation.

## Must-have outcomes
- bundled packs can ship with the app
- packs can be imported from JSON
- packs can be exported
- schema version is enforced
- invalid packs fail clearly and safely

## New files
- `workouttracker/Domain/Models/ProgramPack.swift`
- `workouttracker/Services/Programs/ProgramPackCodec.swift`
- `workouttracker/Services/Programs/ProgramPackValidator.swift`
- `workouttracker/Services/Programs/ProgramImportExportService.swift`

Optional only if needed for embedded routines:
- `workouttracker/Domain/Models/RoutinePackEntry.swift`

## Existing files likely updated
- `workouttracker/App/Seed/SeedCatalog.swift`
- `workouttracker/Resources/Localizable.xcstrings`
- possibly `workouttracker/Services/Backup/BackupService.swift` only if integration is genuinely clean

## Pack format rules
Required:
- versioned schema
- stable ids
- ordered week/day structure
- explicit references

Validate at minimum:
- duplicate ids or stable keys
- invalid week/day ordering
- missing routine or exercise references
- unsupported rule configuration
- invalid numeric ranges
- unsupported schema version

## Collision policy
Make import collision handling explicit. Good options:
- skip existing
- replace existing
- import as copy

## Do not do in PR4
- remote marketplace
- automatic online downloads
- loose malformed-pack auto-repair
- unversioned JSON formats

## Unit tests
Suggested files:
- `workouttrackerTests/Programs/ProgramPackCodecTests.swift`
- `workouttrackerTests/Programs/ProgramPackValidatorTests.swift`

Cover:
- round-trip encode/decode
- schema version persistence
- malformed JSON
- duplicate ids
- missing references
- invalid rule configuration
- unsupported schema version

## Manual validation
- import bundled sample pack
- export a pack and re-import it
- import malformed pack and verify helpful error
- test duplicate import policy behavior

## Acceptance criteria
- bundled packs can be loaded
- exported packs round-trip correctly
- invalid packs fail with clear validation
- schema version is enforced from day one
