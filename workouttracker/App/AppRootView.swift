import SwiftUI

// File: workouttracker/App/AppRootView.swift
//
// What changed:
// - All Home tiles are now actually wired to real screens.
// - Added a Templates tile so template editing is accessible again.
// - Fixed the HomeTile API usage: `destination` is a closure `() -> AnyView`.
//
// Why this lives here:
// - AppRootView is the single place that defines “top-level navigation” for the app.

struct AppRootView: View {
    private let cal = Calendar.current

    var body: some View {
    let env = ProcessInfo.processInfo.environment

    // UI tests can request a deterministic entry point so tests don't depend on Home navigation.
    if env["UITESTS"] == "1", let start = env["UITESTS_START"]?.lowercased() {
        let applyDay = cal.startOfDay(for: Date())
        switch start {
        case "calendar":
            NavigationStack { DayTimelineEntryScreen() }
        case "settings":
            NavigationStack { SettingsScreen() }
        case "templates":
            NavigationStack { TemplatesScreen(applyDay: applyDay) }
        case "workouts":
            NavigationStack { WorkoutSessionsScreen() }
        case "routines":
            NavigationStack { RoutinesScreen() }
        default:
            HomeScreen(tiles: tiles)
        }
    } else {
        HomeScreen(tiles: tiles)
    }
}

    private var tiles: [HomeTile] {
        let applyDay = cal.startOfDay(for: Date())

        return [
            HomeTile(
                title: "Calendar",
                subtitle: "Plan and log your day",
                systemImage: "calendar",
                tint: .accentColor,
                destination: { AnyView(DayTimelineEntryScreen()) }
            ),

            HomeTile(
                title: "Workouts",
                subtitle: "Start sessions and review history",
                systemImage: "dumbbell.fill",
                tint: .orange,
                destination: { AnyView(WorkoutSessionsScreen()) }
            ),

            HomeTile(
                title: "Routines",
                subtitle: "Build plans and reuse them",
                systemImage: "list.bullet.rectangle.portrait",
                tint: .purple,
                destination: { AnyView(RoutinesScreen()) }
            ),

            HomeTile(
                title: "Templates",
                subtitle: "Auto-preload your day",
                systemImage: "wand.and.stars",
                tint: .indigo,
                destination: { AnyView(TemplatesScreen(applyDay: applyDay)) }
            ),

            HomeTile(
                title: "Exercises",
                subtitle: "Browse and edit your library",
                systemImage: "square.grid.2x2.fill",
                tint: .mint,
                destination: { AnyView(ExerciseLibraryScreen()) }
            ),

            HomeTile(
                title: "Progress",
                subtitle: "Streaks, volume, trends",
                systemImage: "chart.line.uptrend.xyaxis",
                tint: .blue,
                destination: { AnyView(ProgressScreen()) }
            ),

            HomeTile(
                title: "Body",
                subtitle: "Measurements and tracking",
                systemImage: "scalemass.fill",
                tint: .green,
                destination: { AnyView(MeasurementsScreen()) }
            ),

            HomeTile(
                title: "Settings",
                subtitle: "Preferences and app info",
                systemImage: "gearshape.fill",
                tint: .gray,
                destination: { AnyView(SettingsScreen()) }
            )
        ]
    }
}
