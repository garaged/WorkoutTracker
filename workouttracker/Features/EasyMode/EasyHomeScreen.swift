import SwiftUI
import SwiftData

struct EasyHomeScreen: View {
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var workoutSessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)])
    private var trackedSessions: [TrackedActivitySession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "easy.home.title", defaultValue: "Ready to move?"))
                        .font(.largeTitle.bold())
                    Text(String(localized: "easy.home.subtitle", defaultValue: "Choose the simplest way to start. You can add details later."))
                        .foregroundStyle(.secondary)
                }

                if let workout = workoutSessions.first(where: \.isUnfinished) {
                    NavigationLink {
                        WorkoutSessionScreen(session: workout)
                    } label: {
                        resumeCard(title: workout.sourceRoutineNameSnapshot ?? String(localized: "easy.home.workout", defaultValue: "Workout"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Easy.Home.Resume")
                } else if let tracked = trackedSessions.first(where: \.isActive) {
                    NavigationLink {
                        TrackedActivityDestinationView(sessionID: tracked.id)
                    } label: {
                        resumeCard(title: String(localized: "easy.home.active_timer", defaultValue: "Active timer"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Easy.Home.Resume")
                }

                Text(String(localized: "easy.home.start_section", defaultValue: "Start something"))
                    .font(.headline)

                entryCard(
                    title: String(localized: "easy.home.follow.title", defaultValue: "Follow a workout"),
                    subtitle: String(localized: "easy.home.follow.subtitle", defaultValue: "Use a routine with exercises in order"),
                    systemImage: "list.bullet.clipboard",
                    tint: .indigo,
                    identifier: "Easy.Home.FollowWorkout"
                ) {
                    WorkoutSessionsScreen()
                }

                entryCard(
                    title: String(localized: "easy.home.freestyle.title", defaultValue: "Gym freestyle"),
                    subtitle: String(localized: "easy.home.freestyle.subtitle", defaultValue: "Choose a machine or exercise as you go"),
                    systemImage: "dumbbell.fill",
                    tint: .orange,
                    identifier: "Easy.Home.GymFreestyle"
                ) {
                    GymFreestyleDraftScreen()
                }

                entryCard(
                    title: String(localized: "easy.home.timer.title", defaultValue: "Just start a timer"),
                    subtitle: String(localized: "easy.home.timer.subtitle", defaultValue: "Pick a style and start immediately"),
                    systemImage: "timer",
                    tint: .teal,
                    identifier: "Easy.Home.JustStartTimer"
                ) {
                    QuickStartLauncherScreen()
                }

                NavigationLink {
                    SettingsScreen()
                } label: {
                    Label(String(localized: "easy.home.settings", defaultValue: "Settings and Pro mode"), systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
                .accessibilityIdentifier("Easy.Home.Settings")
            }
            .padding(18)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(String(localized: "easy.home.navigation_title", defaultValue: "Today"))
        .accessibilityIdentifier("Easy.Home.Screen")
    }

    private func resumeCard(title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(String(localized: "easy.home.resume", defaultValue: "Resume"), systemImage: "play.fill")
                .font(.headline)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func entryCard<Destination: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        identifier: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

private struct GymFreestyleDraftScreen: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "easy.freestyle.draft.title", defaultValue: "Gym freestyle"),
            systemImage: "dumbbell.fill",
            description: Text(String(localized: "easy.freestyle.draft.message", defaultValue: "Exercise-by-exercise quick logging is the next implementation milestone in this draft."))
        )
        .navigationTitle(String(localized: "easy.home.freestyle.title", defaultValue: "Gym freestyle"))
    }
}
