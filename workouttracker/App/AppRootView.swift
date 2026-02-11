import SwiftUI

// File: workouttracker/App/AppRootView.swift
//
// Patch:
// - UI-test-only router via launchEnvironment (UITESTS_START).
// - Default behavior unchanged: HomeScreen remains root.

struct AppRootView: View {
    private let cal = Calendar.current

    var body: some View {
        if let start = uiTestStartRoute {
            uiTestRoot(for: start)
        } else {
            HomeScreen(tiles: tiles)
        }
    }

    // MARK: - UI test routing

    private var uiTestStartRoute: String? {
        let env = ProcessInfo.processInfo.environment
        guard env["UITESTS"] == "1" else { return nil }
        return env["UITESTS_START"]
    }

    @ViewBuilder
    private func uiTestRoot(for start: String) -> some View {
        switch start.lowercased() {
        case "calendar":
            NavigationStack { DayTimelineEntryScreen() }
        case "settings":
            NavigationStack { SettingsScreen() }
        case "session":
            // We boot into Calendar, then DayTimelineScreen (only in this route) will seed+auto-open a session.
            NavigationStack { DayTimelineEntryScreen() }
        default:
            HomeScreen(tiles: tiles)
        }
    }

    // MARK: - Home tiles

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
