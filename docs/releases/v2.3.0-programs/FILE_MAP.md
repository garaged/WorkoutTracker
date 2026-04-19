# v2.3.0 file map

This file explains where new v2.3.0 code should live and why.

## Domain models
- `workouttracker/Domain/Models/TrainingProgram.swift`  
  Core reusable program template.
- `workouttracker/Domain/Models/ProgramWeek.swift`  
  Ordered week structure for a program.
- `workouttracker/Domain/Models/ProgramDay.swift`  
  Ordered training day structure within a week.
- `workouttracker/Domain/Models/ProgramPrescription.swift`  
  Per-exercise target data needed for progression.
- `workouttracker/Domain/Models/ProgramAssignment.swift`  
  User-specific assignment of a program.
- `workouttracker/Domain/Models/ProgramExecutionState.swift`  
  Runtime adherence and progress state.
- `workouttracker/Domain/Models/ProgramCompletedDay.swift`  
  Historical completion records.
- `workouttracker/Domain/Models/ProgramMissedDay.swift`  
  Historical missed-day records.
- `workouttracker/Domain/Models/ProgressionRule.swift`  
  Typed progression logic definitions.
- `workouttracker/Domain/Models/ProgramPack.swift`  
  Versioned import/export pack model.
- `workouttracker/Domain/Models/TrainingProgramTypes.swift`  
  Shared enums and value types for the Programs domain.

## Services
- `workouttracker/Services/Programs/ProgramPlanner.swift`  
  Computes current position and next actionable program day.
- `workouttracker/Services/Programs/ProgramAdherenceService.swift`  
  Computes completion and missed-session summaries.
- `workouttracker/Services/Programs/ProgressionEngine.swift`  
  Applies typed progression rules to results.
- `workouttracker/Services/Programs/ProgramPackCodec.swift`  
  Encodes and decodes versioned pack JSON.
- `workouttracker/Services/Programs/ProgramPackValidator.swift`  
  Validates imported pack structure and references.
- `workouttracker/Services/Programs/ProgramImportExportService.swift`  
  Orchestrates import, validation, collision handling, and export.

## Service output models
- `workouttracker/Services/Programs/Models/ProgramPosition.swift`
- `workouttracker/Services/Programs/Models/PlannedProgramDay.swift`
- `workouttracker/Services/Programs/Models/ProgramAdherenceSummary.swift`
- `workouttracker/Services/Programs/Models/ProgramWeekCompletion.swift`
- `workouttracker/Services/Programs/Models/ProgramRecommendation.swift`
- `workouttracker/Services/Programs/Models/ProgressionDecision.swift`
- `workouttracker/Services/Programs/Models/ProgramPrescriptionAdjustment.swift`

These files exist so planner/progression output remains explicit, testable, and separate from UI state.

## Feature UI
- `workouttracker/Features/Programs/ProgramLibraryScreen.swift`
- `workouttracker/Features/Programs/ProgramDetailScreen.swift`
- `workouttracker/Features/Programs/ProgramAssignmentScreen.swift`
- `workouttracker/Features/Programs/ProgramProgressScreen.swift`
- `workouttracker/Features/Programs/Components/WeekProgressCard.swift`
- `workouttracker/Features/Programs/Components/NextRecommendedActionCard.swift`
- `workouttracker/Features/Programs/Components/MissedSessionCard.swift`
- `workouttracker/Features/Programs/Components/DeloadCueCard.swift`
- `workouttracker/Features/Programs/Components/ProgramDayRow.swift`

## Existing files likely updated
- `workouttracker/Domain/Models/WorkoutRoutine.swift`
- `workouttracker/Domain/Models/WorkoutSession.swift`
- `workouttracker/Services/Workouts/WorkoutSessionService.swift`
- `workouttracker/App/AppRootView.swift`
- `workouttracker/App/Routing/AppRoute.swift`
- `workouttracker/App/Routing/RouteResolver.swift`
- `workouttracker/App/Seed/SeedCatalog.swift`
- `workouttracker/Features/Sessions/WorkoutSessionScreen.swift`
- `workouttracker/Resources/Localizable.xcstrings`
- `workouttrackerUITestHost/workouttrackerUITestHostApp.swift`
