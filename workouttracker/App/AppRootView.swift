import SwiftUI

struct AppRootView: View {
    var body: some View {
        HomeScreen(tiles: tiles)
    }

    private var tiles: [HomeTile] {
        [
            HomeTile(
                title: "Calendar",
                subtitle: "Plan and log your day",
                systemImage: "calendar",
                tint: .accentColor,
                destination: { AnyView(DayTimelineEntryScreen()) }   // ✅ timeline/day view
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
