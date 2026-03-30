# Changelog v1

## v1.0.8

- Fixed a UI-test launch regression where Home Resume no longer opened the active workout session
- Restored test routing to use the same root session-presentation path as the production Home flow

## v1.0.7

Misc. fixes (no more warnings). Rest time counter improvements for full robustness.

## v1.0.6

Routine editing, improving watch sync.

## v1.0.5 Basic exercise image sets, backup/restore including activities

Implement unit selection in Settings.

Sound for rest time: Makes it easy to follow up without keeping an eye on the phone.

Exercise illustration sets:

- workouttracker/Support/ExerciseIllustrationSet.swift
  - Added `maleV1` and user-facing labels for all three bundled illustration families.
- workouttracker/Support/ExerciseIllustrationCatalog.swift
  - Extended the central asset resolver so every stable exercise key can resolve to dummy, female, or male assets.
- workouttracker/Services/Settings/UserPreferences.swift
  - Added a persisted `exerciseIllustrationSet` preference and kept `dummyV1` as the default / reset value.
- workouttracker/Features/Settings/ExerciseIllustrationSetPickerSection.swift
  - Updated the Settings UI to bind to `UserPreferences` and expose all three illustration options.

Backup/restore supporting activities.

## v1.0.4 - Watch support, UI improvements

- Basic Apple Watch support
- Small UI/Usability improvements

## in v1.0.1 (2) - Better communication with users

- Add a super easy “Feedback / Report a bug” button that actually gives useful info.
- Make support routes obvious (Support link + a privacy-friendly way to reach out).

## in v1.0.1 (1) - Session reflections (comments + mood)

- At the end of a session, pop a quick “How did it feel?” step:
  - pick a mood/result in 1–2 taps
  - optionally jot a short note
- Idea is to capture the vibe/context without slowing down logging.

## in v1.0.1 (1) - iPad support

- Make the UI feel right on big screens (Split View, better spacing/density, keyboard-friendly).
- Goal: more of a “coach clipboard” vibe for gym/home.

## in v1.0.1 (1) - Programs / plans (shareable)

- Add real training programs people can download/import.
- Later: let the community submit programs too (but that needs moderation + somewhere to host them).


