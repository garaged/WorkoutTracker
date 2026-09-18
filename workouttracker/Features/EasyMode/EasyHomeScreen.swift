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
                    GymFreestyleLauncherScreen()
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

struct GymFreestyleLauncherScreen: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var workoutSessions: [WorkoutSession]

    @State private var launchedSession: WorkoutSession?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "easy.freestyle.intro", defaultValue: "Start with the machine in front of you. You can add details later."))
                .foregroundStyle(.secondary)

            Button {
                startUnnamedExercise()
            } label: {
                Label(String(localized: "easy.freestyle.start_unnamed", defaultValue: "Start unnamed exercise"), systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("GymFreestyle.StartUnnamed")

            Text(String(localized: "easy.freestyle.start_unnamed.help", defaultValue: "This starts a duration-only exercise. It does not add sets, weight, reps, or a personal record."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle(String(localized: "easy.home.freestyle.title", defaultValue: "Gym freestyle"))
        .navigationDestination(item: $launchedSession) { session in
            GymFreestyleSessionScreen(session: session)
        }
        .alert(String(localized: "easy.freestyle.unavailable", defaultValue: "Cannot start exercise"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func startUnnamedExercise() {
        guard !workoutSessions.contains(where: \.isUnfinished) else {
            errorMessage = String(localized: "easy.freestyle.active_conflict", defaultValue: "Finish or resume the active workout before starting another exercise.")
            return
        }

        let session = WorkoutSession(sourceRoutineNameSnapshot: String(localized: "easy.freestyle.session_name", defaultValue: "Freestyle workout"))
        let exercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: String(localized: "easy.freestyle.generic_name", defaultValue: "Unnamed exercise"),
            trackingStyle: .timeOnly,
            session: session
        )
        session.exercises = [exercise]

        context.insert(session)
        context.insert(exercise)

        do {
            try context.save()
            launchedSession = session
        } catch {
            errorMessage = String(localized: "easy.freestyle.save_failed", defaultValue: "The exercise was not saved. Please try again.")
        }
    }
}

struct GymFreestyleSessionScreen: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context
    @State private var didFinishExercise = false
    @State private var errorMessage: String?

    private var exercise: WorkoutSessionExercise? {
        session.exercises.sorted(by: { $0.order < $1.order }).first
    }

    var body: some View {
        Group {
            if let exercise {
                sessionContent(exercise: exercise)
            } else {
                ContentUnavailableView(
                    String(localized: "easy.freestyle.recovery.title", defaultValue: "Exercise unavailable"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(localized: "easy.freestyle.recovery.message", defaultValue: "Return to Today and try starting the exercise again."))
                )
            }
        }
        .navigationTitle(String(localized: "easy.home.freestyle.title", defaultValue: "Gym freestyle"))
        .accessibilityIdentifier("GymFreestyle.Session.Screen")
        .alert(String(localized: "easy.freestyle.save_failed", defaultValue: "The exercise was not saved. Please try again."), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func sessionContent(exercise: WorkoutSessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(exercise.exerciseNameSnapshot)
                .font(.title.bold())

            if didFinishExercise {
                Label(String(localized: "easy.freestyle.exercise_finished", defaultValue: "Exercise finished"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                Text(String(localized: "easy.freestyle.finished.detail", defaultValue: "No sets or metrics were added. You can finish the workout when you are ready."))
                    .foregroundStyle(.secondary)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent(String(localized: "easy.freestyle.elapsed", defaultValue: "Exercise time")) {
                        Text(TrackedActivitySummaryBuilder.formatDuration(TimeInterval(session.elapsedSeconds())))
                            .monospacedDigit()
                    }
                }

                Text(String(localized: "easy.freestyle.duration_only", defaultValue: "Duration only — no sets, reps, weight, or rest are being recorded."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(String(localized: "easy.freestyle.finish_exercise", defaultValue: "Finish exercise")) {
                    do {
                        try FreestyleWorkoutRecorder().finish(exercise, in: session, context: context)
                        didFinishExercise = true
                    } catch {
                        errorMessage = String(localized: "easy.freestyle.save_failed", defaultValue: "The exercise was not saved. Please try again.")
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("GymFreestyle.FinishExercise")
            }

            Spacer()
        }
        .padding()
    }
}
