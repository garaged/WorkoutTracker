import SwiftUI

private struct WatchTrackedActivityShortcut: Identifiable {
    let id: String
    let titleKey: String
    let defaultTitle: String
    let systemImage: String
    let activityKindRaw: String
    let environmentRaw: String

    var title: String {
        NSLocalizedString(titleKey, bundle: .main, value: defaultTitle, comment: "")
    }
}

private let trackedActivityShortcuts: [WatchTrackedActivityShortcut] = [
    .init(
        id: "walking",
        titleKey: "watch.activities.shortcut.walk",
        defaultTitle: "Walk",
        systemImage: "figure.walk",
        activityKindRaw: "walking",
        environmentRaw: "outdoor"
    ),
    .init(
        id: "running",
        titleKey: "watch.activities.shortcut.run",
        defaultTitle: "Run",
        systemImage: "figure.run",
        activityKindRaw: "running",
        environmentRaw: "outdoor"
    ),
    .init(
        id: "hiking",
        titleKey: "watch.activities.shortcut.hike",
        defaultTitle: "Hike",
        systemImage: "figure.hiking",
        activityKindRaw: "hiking",
        environmentRaw: "outdoor"
    ),
    .init(
        id: "yoga",
        titleKey: "watch.activities.shortcut.yoga",
        defaultTitle: "Yoga",
        systemImage: "figure.yoga",
        activityKindRaw: "yoga",
        environmentRaw: "indoor"
    )
]

struct WatchWorkoutShortcutsView: View {
    @ObservedObject var client: WatchConnectivityClient
    @ObservedObject var launcher: WatchRouteLauncher
    private let presentation = WatchPresentationEvaluator()

    private var showsCurrentTrackedActivitySection: Bool {
        client.nowPlaying.isTrackedActivitySession &&
        (
            client.nowPlaying.isActiveSession ||
            client.nowPlaying.isPaused ||
            client.hasRecoverableNowPlayingSession ||
            client.isRecoveringRecentSession
        )
    }

    var body: some View {
        List {
            if showsCurrentTrackedActivitySection {
                Section(String(localized: "watch.activities.section.current_activity", defaultValue: "Current Activity")) {
                    Button {
                        launcher.armAutoOpenControls()
                        client.send(.init(kind: .resumeCurrentTrackedActivity, sessionID: client.nowPlaying.sessionID))
                        client.requestState()
                    } label: {
                        Label(
                            presentation.currentActivityPrimaryActionTitle(isPaused: client.nowPlaying.isPaused),
                            systemImage: client.nowPlaying.isPaused ? "play.circle.fill" : "figure.walk.motion"
                        )
                    }
                    .disabled(!client.canSendCommands)
                    .accessibilityIdentifier("Watch.Shortcuts.PrimaryAction")

                    Button {
                        launcher.openNowPlaying()
                    } label: {
                        Label(
                            presentation.currentActivityControlsActionTitle(isRecoveringRecentSession: client.isRecoveringRecentSession),
                            systemImage: "applewatch.watchface"
                        )
                    }
                    .accessibilityIdentifier("Watch.Shortcuts.OpenCurrentActivity")

                    Text(client.trackedActivityStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("Watch.Shortcuts.TrackedStatus")
                }
            }

            Section(String(localized: "watch.activities.section.start_activity", defaultValue: "Start Activity")) {
                ForEach(trackedActivityShortcuts) { shortcut in
                    Button {
                        launcher.armAutoOpenControls()
                        client.send(
                            .init(
                                kind: .startTrackedActivity,
                                trackedActivityKindRaw: shortcut.activityKindRaw,
                                activityEnvironmentRaw: shortcut.environmentRaw
                            )
                        )
                    } label: {
                        Label(shortcut.title, systemImage: shortcut.systemImage)
                    }
                    .disabled(!client.canSendCommands)
                }
            }

            Section(String(localized: "watch.activities.section.quick_start_workouts", defaultValue: "Quick Start Workouts")) {
                if client.nowPlaying.quickStartRoutines.isEmpty {
                    Text(String(localized: "watch.activities.empty.no_routines", defaultValue: "No routines yet"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(client.nowPlaying.quickStartRoutines) { routine in
                        Button {
                            launcher.armAutoOpenControls()
                            client.send(.init(kind: .startRoutine, routineID: routine.id))
                        } label: {
                            Label(routine.name, systemImage: "play.circle.fill")
                        }
                        .disabled(!client.canSendCommands)
                    }
                }
            }

            if let transportStatusText = client.transportStatusText {
                Section {
                    Label(transportStatusText, systemImage: client.transportStatusSymbol)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.carousel)
        .accessibilityIdentifier("Watch.Shortcuts.Screen")
        .navigationTitle(String(localized: "watch.activities.title", defaultValue: "Workout"))
        .onAppear { client.requestState() }
        .onChange(of: client.hasRecoverableNowPlayingSession) { _, hasSession in
            launcher.consumeAutoOpenIfPossible(hasActiveSession: hasSession)
        }
    }
}
