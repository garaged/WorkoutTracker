// workouttracker/App/AppRootView.swift
import SwiftUI
import SwiftData
import Combine

enum RootDestination: String, CaseIterable, Identifiable {
    case home
    case routines
    case history
    case progress
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .routines: String(localized: "Routines")
        case .history: String(localized: "History")
        case .progress: String(localized: "Progress")
        case .settings: String(localized: "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .routines: "list.bullet.rectangle"
        case .history: "clock.arrow.circlepath"
        case .progress: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape"
        }
    }
}

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.platform) private var platform

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @Query
    private var activities: [Activity]

    @State private var didSeed = false
    @AppStorage("workouttracker.starterPackVersion") private var starterPackVersion = 0
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: RootDestination? = .home
    @State private var presentedSessionRoute: SessionPresentationRoute? = nil
    @State private var timelineJump: TimelineJump? = nil

    private struct TimelineJump: Identifiable {
        let id = UUID()
        let day: Date
    }

    private let cal = Calendar.current
    private let sessionResumePlanner = SessionResumePlanner()
    private let routeResolver = RouteResolver()
    private let snapshotBuilder = CurrentSessionSnapshotBuilder()

    var body: some View {
        Group {
            if shouldWaitForStarterPackBootstrap {
                bootstrapView
            } else if let start = uiTestStartRoute {
                uiTestRoot(for: start)
            } else {
                appShellRoot
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("workouttracker.openTimelineForDate"))) { note in
            guard let date = note.object as? Date else { return }
            open(.calendarDay(date: date))
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("workouttracker.openURLForTesting"))) { note in
            guard ProcessInfo.processInfo.environment["UITESTS"] == "1",
                  let url = note.object as? URL,
                  let route = routeResolver.route(for: url, sessions: sessions, routines: routines) else {
                return
            }
            open(route)
        }
        .fullScreenCover(item: $timelineJump) { jump in
            NavigationStack {
                DayTimelineEntryScreen(initialDay: jump.day)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(AppFormatting.localized("Close")) { timelineJump = nil }
                        }
                    }
            }
        }
        .task {
            guard !didSeed else { return }

            guard ProcessInfo.processInfo.environment["UITESTS"] != "1" else {
                didSeed = true
                return
            }

            StarterPackSeeder.seedIfNeeded(context: modelContext)
            didSeed = true

            do {
                _ = try ExerciseIllustrationBackfill.migrateIfNeeded(context: modelContext)
            } catch {
                assertionFailure("Exercise illustration migration failed: \(error)")
            }
        }
        .onOpenURL { url in
            guard let route = routeResolver.route(for: url, sessions: sessions, routines: routines) else {
                return
            }
            open(route)
        }
    }

    private var shouldWaitForStarterPackBootstrap: Bool {
        ProcessInfo.processInfo.environment["UITESTS"] != "1" &&
        starterPackVersion == 0 &&
        !didSeed
    }

    private var bootstrapView: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)

                Text(AppFormatting.localized("Preparing starter pack…"))
                    .font(.headline)

                Text(AppFormatting.localized("This only happens on first launch so Workout activities have routines ready immediately."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }

    private var sidebar: some View {
        List(RootDestination.allCases, selection: $selection) { dest in
            Label(dest.title, systemImage: dest.systemImage)
                .tag(dest as RootDestination?)
        }
        .navigationTitle(AppFormatting.localized("Workout Tracker"))
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func detail(for dest: RootDestination) -> some View {
        switch dest {
        case .home:
            HomeScreen(
                tiles: tiles,
                onResumeRoute: open
            )
        case .routines:
            RoutinesScreen(onOpenSession: { session in
                open(sessionResumePlanner.resumeRoute(for: session) ?? sessionResumePlanner.openRoute(for: session))
            })
        case .history:
            HistoryRootPlaceholder()
        case .progress:
            ProgressScreen()
        case .settings:
            SettingsScreen()
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
            NavigationStack { DayTimelineEntryScreen() }
        case "routines":
            NavigationStack {
                RoutinesScreen(onOpenSession: { session in
                    open(sessionResumePlanner.resumeRoute(for: session) ?? sessionResumePlanner.openRoute(for: session))
                })
            }
        case "workouts":
            NavigationStack { WorkoutSessionsScreen() }
        case "home":
            appShellRoot
        default:
            appShellRoot
        }
    }

    // MARK: - Home tiles

    private var tiles: [HomeTile] {
        let applyDay = cal.startOfDay(for: Date())

        return [
            HomeTile(
                title: String(localized: "Calendar"),
                subtitle: String(localized: "Plan and log your day"),
                systemImage: "calendar",
                tint: .accentColor,
                destination: { AnyView(DayTimelineEntryScreen()) }
            ),
            HomeTile(
                title: String(localized: "Workouts"),
                subtitle: String(localized: "Start sessions and review history"),
                systemImage: "dumbbell.fill",
                tint: .orange,
                destination: { AnyView(WorkoutSessionsScreen()) }
            ),
            HomeTile(
                title: String(localized: "Routines"),
                subtitle: String(localized: "Build plans and reuse them"),
                systemImage: "list.bullet.rectangle.portrait",
                tint: .purple,
                destination: {
                    AnyView(
                        RoutinesScreen(onOpenSession: { session in
                            open(sessionResumePlanner.resumeRoute(for: session) ?? sessionResumePlanner.openRoute(for: session))
                        })
                    )
                }
            ),
            HomeTile(
                title: String(localized: "Schedule templates"),
                subtitle: String(localized: "Plans that auto-preload your day"),
                systemImage: "wand.and.stars",
                tint: .indigo,
                destination: { AnyView(TemplatesScreen(applyDay: applyDay)) }
            ),
            HomeTile(
                title: String(localized: "Exercises"),
                subtitle: String(localized: "Browse and edit your library"),
                systemImage: "square.grid.2x2.fill",
                tint: .mint,
                destination: { AnyView(ExerciseLibraryScreen()) }
            ),
            HomeTile(
                title: String(localized: "Progress"),
                subtitle: String(localized: "Streaks, volume, trends"),
                systemImage: "chart.line.uptrend.xyaxis",
                tint: .blue,
                destination: { AnyView(ProgressScreen()) }
            ),
            HomeTile(
                title: String(localized: "Body"),
                subtitle: String(localized: "Measurements and tracking"),
                systemImage: "scalemass.fill",
                tint: .green,
                destination: { AnyView(MeasurementsScreen()) }
            ),
            HomeTile(
                title: String(localized: "Settings"),
                subtitle: String(localized: "Preferences and app info"),
                systemImage: "gearshape.fill",
                tint: .gray,
                destination: { AnyView(SettingsScreen()) }
            )
        ]
    }

    private struct HistoryRootPlaceholder: View {
        var body: some View {
            ContentUnavailableView(AppFormatting.localized("History"),
                systemImage: "clock.arrow.circlepath",
                description: Text(AppFormatting.localized("Wire your existing History screen here."))
            )
            .navigationTitle(AppFormatting.localized("History"))
        }
    }

    private var compactRoot: some View {
        NavigationStack {
            HomeScreen(
                tiles: tiles,
                onResumeRoute: open
            )
            .navigationDestination(item: $presentedSessionRoute) { route in
                WorkoutSessionScreen(
                    session: route.session,
                    initialResumeTarget: route.initialResumeTarget,
                    initialRoute: route.launchRoute
                )
            }
        }
    }

    private var splitRoot: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack {
                detail(for: selection ?? .home)
                    .navigationDestination(item: $presentedSessionRoute) { route in
                        WorkoutSessionScreen(
                            session: route.session,
                            initialResumeTarget: route.initialResumeTarget,
                            initialRoute: route.launchRoute
                        )
                    }
            }
        }
    }

    private func open(_ route: AppRoute) {
        switch route {
        case .home:
            selection = .home
            presentedSessionRoute = nil
            timelineJump = nil

        case .calendarDay(let date):
            selection = .home
            timelineJump = TimelineJump(day: cal.startOfDay(for: date))

        case .routine:
            selection = .routines

        case .session, .sessionExercise, .sessionRest:
            guard let presentation = sessionPresentationRoute(for: route) else {
                selection = .home
                presentedSessionRoute = nil
                return
            }

            let sameSession = presentedSessionRoute?.session.persistentModelID == presentation.session.persistentModelID
            let sameLaunchRoute = presentedSessionRoute?.launchRoute == presentation.launchRoute

            if sameSession && sameLaunchRoute {
                presentedSessionRoute = nil
                Task { @MainActor in
                    presentedSessionRoute = presentation
                }
            } else {
                presentedSessionRoute = presentation
            }
        }
    }

    private func sessionPresentationRoute(for route: AppRoute) -> SessionPresentationRoute? {
        guard let sessionID = route.sessionID,
              let session = sessions.first(where: { $0.id == sessionID }) else {
            return nil
        }

        let initialResumeTarget: SessionResumeTarget?
        switch route {
        case .sessionExercise(_, let exerciseID):
            initialResumeTarget = explicitResumeTarget(for: session, exerciseID: exerciseID)
        case .sessionRest:
            initialResumeTarget = sessionResumePlanner.currentResumeTarget(for: session)
        case .session:
            initialResumeTarget = sessionResumePlanner.currentResumeTarget(for: session)
        default:
            initialResumeTarget = nil
        }

        return SessionPresentationRoute(
            session: session,
            initialResumeTarget: initialResumeTarget,
            launchRoute: route
        )
    }

    private func explicitResumeTarget(
        for session: WorkoutSession,
        exerciseID: UUID
    ) -> SessionResumeTarget? {
        guard let exercise = session.exercises.first(where: { $0.id == exerciseID }) else {
            return sessionResumePlanner.currentResumeTarget(for: session)
        }

        let orderedSets = exercise.setLogs.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        if let nextIncomplete = orderedSets.first(where: { !$0.completed }) {
            return SessionResumeTarget(
                sessionID: session.id,
                exerciseID: exercise.id,
                setID: nextIncomplete.id,
                reason: .nextIncompleteSet
            )
        }

        if let first = orderedSets.first {
            return SessionResumeTarget(
                sessionID: session.id,
                exerciseID: exercise.id,
                setID: first.id,
                reason: .fallbackLastSet
            )
        }

        return sessionResumePlanner.currentResumeTarget(for: session)
    }

    private var appShellRoot: some View {
        Group {
            if platform.isPad && platform.prefersSplitNavigation {
                splitRoot
            } else {
                compactRoot
            }
        }
    }

    private var currentSessionSnapshot: CurrentSessionSnapshot {
        snapshotBuilder.build(sessions: sessions, activities: activities)
    }
}
