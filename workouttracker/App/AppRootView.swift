// workouttracker/App/AppRootView.swift
import SwiftUI
import SwiftData
import Combine
import AppIntents

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
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var pendingIntentURL: URL? = nil

    private struct TimelineJump: Identifiable {
        let id = UUID()
        let day: Date
    }

    private let cal = Calendar.current
    private let sessionResumePlanner = SessionResumePlanner()
    private let routeResolver = RouteResolver()
    private let systemIntegrationRouteResolver = SystemIntegrationRouteResolver()
    private let snapshotBuilder = CurrentSessionSnapshotBuilder()

    var body: some View {
        rootContent
            .onReceive(openTimelinePublisher, perform: handleOpenTimelineNotification)
            .onReceive(openURLForTestingPublisher, perform: handleOpenURLForTestingNotification)
            .onReceive(watchOpenRequestPublisher, perform: handleWatchOpenRequestNotification)
            .fullScreenCover(item: $timelineJump, content: timelineJumpCover)
            .task { await handleInitialTask() }
            .onAppear(perform: handleAppear)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(oldPhase, newPhase)
            }
            .onChange(of: sessions.count) { _, _ in
                handleSessionsChanged()
            }
            .onChange(of: routines.count) { _, _ in
                handleRoutinesChanged()
            }
            .onChange(of: shortcutRoutineFingerprint) { _, _ in
                handleShortcutRoutineFingerprintChanged()
            }
            .onReceive(liveActivityRefreshTimer) { _ in
                handleLiveActivityRefreshTick()
            }
            .onOpenURL(perform: handleOpenURL)
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
                onResumeRoute: { route in
                    open(route)
                }
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
    
    private var rootContent: some View {
        Group {
            if shouldWaitForStarterPackBootstrap {
                bootstrapView
            } else if let start = uiTestStartRoute {
                uiTestRoot(for: start)
            } else {
                appShellRoot
            }
        }
    }

    private var openTimelinePublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: Notification.Name("workouttracker.openTimelineForDate"))
    }

    private var activitiesByID: [UUID: Activity] {
        Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
    }

    private var openURLForTestingPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: Notification.Name("workouttracker.openURLForTesting"))
    }

    private var watchOpenRequestPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: .workoutWatchOpenRequested)
    }

    private var liveActivityRefreshTimer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 15, on: .main, in: .common).autoconnect()
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
                onResumeRoute: { route in
                    open(route)
                }
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


    private func refreshPendingIntentURLIfNeeded(forceReload: Bool = false) {
        guard (forceReload || pendingIntentURL == nil),
              let url = IntentLaunchBridge.peekPendingURL() else {
            return
        }

        pendingIntentURL = url
    }

    private func attemptPendingIntentRouteResolution() {
        guard let url = pendingIntentURL else { return }

        let resolution = systemIntegrationRouteResolver.resolve(
            url: url,
            sessions: sessions,
            routines: routines,
            activitiesByID: activitiesByID
        )

        defer {
            IntentLaunchBridge.clearPendingURL()
            pendingIntentURL = nil
        }

        guard let route = resolution.route else { return }
        open(route, preserveLaunchRoute: true)
    }

    private func open(_ route: AppRoute, preserveLaunchRoute: Bool = false) {
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
            guard let presentation = sessionPresentationRoute(
                for: route,
                preserveLaunchRoute: preserveLaunchRoute
            ) else {
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

    private func sessionPresentationRoute(
        for route: AppRoute,
        preserveLaunchRoute: Bool
    ) -> SessionPresentationRoute? {
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
            launchRoute: preserveLaunchRoute ? route : nil
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

    private var shortcutRoutineFingerprint: [String] {
        routines
            .map { "\($0.id.uuidString)|\($0.name)|\($0.notes ?? "")" }
            .sorted()
    }
    
    private func handleOpenTimelineNotification(_ note: Notification) {
        guard let date = note.object as? Date else { return }
        open(.calendarDay(date: date))
    }

    private func handleOpenURLForTestingNotification(_ note: Notification) {
        guard ProcessInfo.processInfo.environment["UITESTS"] == "1",
              let url = note.object as? URL else {
            return
        }

        let resolution = systemIntegrationRouteResolver.resolve(
            url: url,
            sessions: sessions,
            routines: routines,
            activitiesByID: activitiesByID
        )

        guard let route = resolution.route else { return }
        open(route, preserveLaunchRoute: true)
    }

    private func handleWatchOpenRequestNotification(_ note: Notification) {
        refreshPendingIntentURLIfNeeded(forceReload: true)

        guard scenePhase == .active else { return }
        attemptPendingIntentRouteResolution()
    }

    @ViewBuilder
    private func timelineJumpCover(_ jump: TimelineJump) -> some View {
        NavigationStack {
            DayTimelineEntryScreen(initialDay: jump.day)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(AppFormatting.localized("Close")) { timelineJump = nil }
                    }
                }
        }
    }

    private func handleInitialTask() async {
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

    private func handleAppear() {
        refreshPendingIntentURLIfNeeded()
        attemptPendingIntentRouteResolution()
        syncSystemIntegrations()
    }

    private func handleScenePhaseChange(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        if newPhase == .active {
            refreshPendingIntentURLIfNeeded()
            attemptPendingIntentRouteResolution()
            syncSystemIntegrations()
            return
        }

        if oldPhase == .active {
            syncLiveActivity()
        }
    }

    private func handleSessionsChanged() {
        attemptPendingIntentRouteResolution()
        syncLiveActivity()
    }

    private func handleRoutinesChanged() {
        attemptPendingIntentRouteResolution()
        syncLiveActivity()
    }

    private func handleShortcutRoutineFingerprintChanged() {
        guard ProcessInfo.processInfo.environment["UITESTS"] != "1" else { return }
        WorkoutTrackerShortcutsProvider.updateAppShortcutParameters()
    }

    private func handleLiveActivityRefreshTick() {
        guard scenePhase == .active,
              ProcessInfo.processInfo.environment["UITESTS"] != "1" else { return }
        syncLiveActivity()
    }

    private func handleOpenURL(_ url: URL) {
        let resolution = systemIntegrationRouteResolver.resolve(
            url: url,
            sessions: sessions,
            routines: routines,
            activitiesByID: activitiesByID
        )

        guard let route = resolution.route else { return }
        open(route, preserveLaunchRoute: true)
    }
    
    private func syncSystemIntegrations() {
        WidgetRefreshCoordinator().refresh(context: modelContext)
        syncLiveActivity()
    }

    private func syncLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        let snapshot = snapshotBuilder.buildWidgetSnapshot(context: modelContext)

        Task { @MainActor in
            await LiveActivityCoordinator().sync(using: snapshot)
        }
    }
}
