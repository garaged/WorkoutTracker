# Contributing a Program to the Catalog (V2)

This app ships an optional in-bundle catalog file: `program_catalog.json`.

## Rules (must follow)
- The catalog file must be a Program Pack V2 (`format_version: 2`).
- Programs must be schedulable:
  - Every workout day must reference a routine slug:
    - `reference: { kind: "routine", slug: "..." }`
- Routines must reference exercises by slug:
  - `exercise_slug: "..."`

## Recommended workflow
1) Add new exercises (if needed) to `exercises[]`
2) Add new routine(s) to `routines[]`
3) Add a new program to `programs[]` referencing those routine slugs
4) Run the app:
   - Programs → Catalog → Add → Schedule → Start
   - Confirm exercises appear in the workout screen

## Naming conventions
- Use stable slugs:
  - `beginner-full-body-a`
  - `hypertrophy-upper-lower-8w`
- Keep routine names user-friendly:
  - “Full Body A”
  - “Upper (Push)”
- Keep program names user-friendly + duration:
  - “Beginner Strength (4 weeks)”
