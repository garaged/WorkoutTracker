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

    var body: some View {
        Group {
            if shouldWaitForStarterPackBootstrap {
                bootstrapView
            } else if let start = uiTestStartRoute {
                uiTestRoot(for: start)
            } else if platform.prefersSplitNavigation {
                splitRoot
            } else {
                compactRoot
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("workouttracker.openTimelineForDate"))) { note in
            guard let date = note.object as? Date else { return }
            timelineJump = TimelineJump(day: cal.startOfDay(for: date))
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
                onResumeSession: openSession
            )
        case .routines:
            RoutinesScreen()
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
            NavigationStack { RoutinesScreen() }
        case "workouts":
            NavigationStack { WorkoutSessionsScreen() }
        case "home":
            compactRoot
        default:
            compactRoot
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
                destination: { AnyView(RoutinesScreen()) }
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
                onResumeSession: openSession
            )
            .navigationDestination(item: $presentedSessionRoute) { route in
                WorkoutSessionScreen(
                    session: route.session,
                    initialResumeTarget: route.initialResumeTarget
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
                            initialResumeTarget: route.initialResumeTarget
                        )
                    }
            }
        }
    }

    private func openSession(_ session: WorkoutSession) {
        let route = SessionPresentationRoute(
            session: session,
            initialResumeTarget: sessionResumePlanner.target(for: session)
        )

        let sameSession = presentedSessionRoute?.session.persistentModelID == session.persistentModelID

        if sameSession {
            presentedSessionRoute = nil
            Task { @MainActor in
                presentedSessionRoute = route
            }
        } else {
            presentedSessionRoute = route
        }
    }
}
