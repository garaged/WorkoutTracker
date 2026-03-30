import AppIntents

struct WorkoutTrackerShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRoutineIntent(),
            phrases: [
                "Start a routine in \(.applicationName)",
                "Start \(\.$routine) in \(.applicationName)",
                "Begin \(\.$routine) in \(.applicationName)"
            ],
            shortTitle: "Start Routine",
            systemImageName: "play.circle"
        )

        AppShortcut(
            intent: ResumeWorkoutIntent(),
            phrases: [
                "Resume workout in \(.applicationName)",
                "Resume my session in \(.applicationName)"
            ],
            shortTitle: "Resume Workout",
            systemImageName: "arrow.clockwise.circle"
        )

        AppShortcut(
            intent: GoToCurrentSessionIntent(),
            phrases: [
                "Go to current session in \(.applicationName)",
                "Open current workout in \(.applicationName)"
            ],
            shortTitle: "Current Session",
            systemImageName: "figure.strengthtraining.traditional"
        )

        AppShortcut(
            intent: StartRestTimerIntent(),
            phrases: [
                "Start rest timer in \(.applicationName)",
                "Begin rest in \(.applicationName)"
            ],
            shortTitle: "Start Rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: FinishCurrentSessionIntent(),
            phrases: [
                "Finish current session in \(.applicationName)",
                "Finish workout in \(.applicationName)"
            ],
            shortTitle: "Finish Session",
            systemImageName: "checkmark.circle"
        )
    }
}
