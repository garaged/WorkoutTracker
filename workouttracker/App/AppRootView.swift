// workouttracker/App/AppRootView.swift
import SwiftUI
import SwiftData
import Combine

enum RootDestination: String, CaseIterable, Identifiable {
    case home
    case routines
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .routines: "Routines"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .routines: "list.bullet.rectangle"
        case .history: "clock.arrow.circlepath"
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
    
    @State private var timelineJump: TimelineJump? = nil

    private struct TimelineJump: Identifiable {
        let id = UUID()
        let day: Date
    }

    private let cal = Calendar.current

    var body: some View {
        Group {
            if shouldWaitForStarterPackBootstrap {
                bootstrapView
            } else if let start = uiTestStartRoute {
                uiTestRoot(for: start)
            } else if platform.prefersSplitNavigation {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebar
                } detail: {
                    NavigationStack {
                        detail(for: selection ?? .home)
                    }
                }
            } else {
                NavigationStack {
                    HomeScreen(tiles: tiles)
                }
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
                            Button("Close") { timelineJump = nil }
                        }
                    }
            }
        }
        .task {
            // Seed once, across iPhone + iPad paths.
            guard !didSeed else { return }

            // Don’t mutate persistent store during UITests.
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

                Text("Preparing starter pack…")
                    .font(.headline)

                Text("This only happens on first launch so Workout activities have routines ready immediately.")
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
        .navigationTitle("Workout Tracker")
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func detail(for dest: RootDestination) -> some View {
        switch dest {
        case .home:
            HomeScreen(tiles: tiles)
        case .routines:
            RoutinesScreen()
        case .history:
            HistoryRootPlaceholder()
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
        default:
            NavigationStack { HomeScreen(tiles: tiles) }
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

    private struct HistoryRootPlaceholder: View {
        var body: some View {
            ContentUnavailableView(
                "History",
                systemImage: "clock.arrow.circlepath",
                description: Text("Wire your existing History screen here.")
            )
            .navigationTitle("History")
        }
    }
}
