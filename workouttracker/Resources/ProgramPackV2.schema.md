# Program Pack V2 Schema (Workout Tracker)

Program Packs are offline-first “program bundles” that can be shipped in-app (`program_catalog.json`) or shared via export/import.

V2 is **portable across installs**:
- Programs reference routines by **slug**, not UUID.
- Routines reference exercises by **slug**, not UUID.
- The app installs/links assets into the local database and persists a **slug → UUID** mapping.

## Top-level format

A Program Pack V2 JSON file is a single object with:

Required:
- `format_version` (number) — must be `2`
- `exercises` (array)
- `routines` (array)
- `programs` (array)

Optional:
- `generated_at` (string, ISO-8601)

Minimal valid shape:

```json
{
  "format_version": 2,
  "generated_at": "2026-02-22T00:00:00Z",
  "exercises": [],
  "routines": [],
  "programs": []
}
```

## Slug rules

Slugs are stable identifiers used for portability.

Recommended constraints:
- lowercase
- `a-z`, `0-9`, `-`
- no spaces
- unique within each namespace:
  - `exercise.slug` unique within `exercises`
  - `routine.slug` unique within `routines`
  - `program.slug` unique within `programs`

Examples:
- ✅ `goblet-squat`
- ✅ `beginner-full-body-a`
- ✅ `beginner-strength-4w`
- ❌ `Goblet Squat`
- ❌ `beginner_full_body_a`

## Schedulable rule (V2 requirement)

A program is **schedulable** only if:

1) Every training day that represents a workout includes a block containing a routine reference:

```json
"reference": { "kind": "routine", "slug": "<routine-slug>" }
```

2) The referenced routine slug exists in `routines[]` **or** is already installed locally (from prior imports/catalog installs).

If a program violates this rule, the app should:
- show **Missing routines**
- list missing routine slugs
- disable scheduling until assets are installed

## Schema details

### ExerciseDTO

Required:
- `slug` (string)
- `name` (string)
- `modality` (string) — should match `ExerciseModality` raw values (e.g. `strength`, `cardio`, `mobility`)

Optional:
- `instructions` (string)
- `notes` (string)
- `equipment_tags` (string[])

Example:

```json
{
  "slug": "goblet-squat",
  "name": "Goblet Squat",
  "modality": "strength",
  "equipment_tags": ["dumbbell"],
  "instructions": "Keep torso tall, elbows inside knees.",
  "notes": "Start light and focus on depth."
}
```

### RoutineDTO

Required:
- `slug` (string)
- `name` (string)
- `items` (RoutineItemDTO[])

Optional:
- `notes` (string)

Example:

```json
{
  "slug": "beginner-full-body-a",
  "name": "Beginner Full Body A",
  "notes": "Leave 1–2 reps in reserve.",
  "items": []
}
```

### RoutineItemDTO

Required:
- `order` (number)
- `exercise_slug` (string) — must exist in `exercises[].slug`
- `tracking_style` (string) — should match `ExerciseTrackingStyle` raw values (e.g. `strength`)
- `set_plans` (SetPlanDTO[])

Optional:
- `notes` (string)

Example:

```json
{
  "order": 1,
  "exercise_slug": "goblet-squat",
  "tracking_style": "strength",
  "notes": "Controlled eccentric.",
  "set_plans": [
    { "order": 1, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" },
    { "order": 2, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" },
    { "order": 3, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" }
  ]
}
```

### SetPlanDTO

Required:
- `order` (number)

Optional fields (use only what makes sense for the tracking style):
- `target_reps` (number)
- `target_weight` (number)
- `weight_unit` (string) — `kg` / `lb`
- `target_duration_seconds` (number)
- `target_distance` (number)
- `target_rpe` (number)
- `rest_seconds` (number)

Example:

```json
{ "order": 1, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" }
```

## Programs schema (TrainingProgram)

Programs in V2 reuse the app’s `TrainingProgram / TrainingWeek / TrainingDay / TrainingBlock` structure.

### TrainingProgram

Required:
- `id` (UUID string)
- `slug` (string)
- `name` (string)
- `weeks` (TrainingWeek[])

Recommended optional metadata:
- `summary` (string)
- `author` (string)
- `level` (string) — `beginner` / `intermediate` / `advanced` / `unknown`
- `tags` (string[])
- `equipment` (string[])

### TrainingWeek

Required:
- `index` (number) — recommended 1-based
- `days` (TrainingDay[])

Optional:
- `title` (string)
- `goal` (string)

### TrainingDay

Required:
- `index` (number) — recommended 1-based (the app may accept 0-based too)
- `title` (string)
- `blocks` (TrainingBlock[])

Optional:
- `focus` (string)

### TrainingBlock

Required:
- `kind` (string) — `workout`, `rest`, `cardio`, `mobility`, `accessories`, `notes`
- `title` (string)

Optional:
- `estimated_minutes` (number)
- `notes` (string)
- `reference` (object)

Routine reference (required for schedulable workout days):

```json
{
  "kind": "workout",
  "title": "Routine",
  "estimated_minutes": 60,
  "reference": { "kind": "routine", "slug": "beginner-full-body-a" }
}
```

## Full worked example (small)

```json
{
  "format_version": 2,
  "generated_at": "2026-02-22T00:00:00Z",
  "exercises": [
    { "slug": "goblet-squat", "name": "Goblet Squat", "modality": "strength" }
  ],
  "routines": [
    {
      "slug": "seed-full-body-a",
      "name": "Seed Full Body A",
      "items": [
        {
          "order": 1,
          "exercise_slug": "goblet-squat",
          "tracking_style": "strength",
          "set_plans": [
            { "order": 1, "target_reps": 8, "rest_seconds": 90, "weight_unit": "kg" }
          ]
        }
      ]
    }
  ],
  "programs": [
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "slug": "seed-program-v2",
      "name": "Seed Program V2",
      "level": "beginner",
      "weeks": [
        {
          "index": 1,
          "title": "Week 1",
          "days": [
            {
              "index": 1,
              "title": "Full Body A",
              "blocks": [
                {
                  "kind": "workout",
                  "title": "Routine",
                  "estimated_minutes": 45,
                  "reference": { "kind": "routine", "slug": "seed-full-body-a" }
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## Contributor checklist

Before submitting a new catalog update or pack:

- [ ] `format_version` is `2`
- [ ] Each `exercise.slug` is unique
- [ ] Each `routine.slug` is unique
- [ ] Each `program.slug` is unique
- [ ] Every routine item references an existing `exercise_slug`
- [ ] Every workout day includes a routine `reference.slug`
- [ ] Keys are `snake_case` (`exercise_slug`, `format_version`, `estimated_minutes`, etc.)
- [ ] Validate by importing the pack and scheduling the program
- [ ] Start the scheduled workout and confirm exercises appear
