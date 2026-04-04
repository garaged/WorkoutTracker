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

    var body: some View {
        List {
            if client.nowPlaying.isActiveSession, client.nowPlaying.isTrackedActivitySession {
                Section(String(localized: "watch.activities.section.current_activity", defaultValue: "Current Activity")) {
                    Button {
                        launcher.armAutoOpenControls()
                        client.send(.init(kind: .resumeCurrentTrackedActivity, sessionID: client.nowPlaying.sessionID))
                        client.requestState()
                    } label: {
                        Label(
                            client.nowPlaying.isPaused
                                ? String(localized: "watch.activities.action.resume_activity", defaultValue: "Resume Activity")
                                : String(localized: "watch.activities.action.open_activity", defaultValue: "Open Activity"),
                            systemImage: client.nowPlaying.isPaused ? "play.circle.fill" : "figure.walk.motion"
                        )
                    }
                    .disabled(!client.canSendCommands)

                    Button {
                        launcher.openNowPlaying()
                    } label: {
                        Label(
                            String(localized: "watch.activities.action.open_controls", defaultValue: "Open Controls"),
                            systemImage: "applewatch.watchface"
                        )
                    }
                }
            }

            if client.nowPlaying.isActiveSession, client.nowPlaying.isStrengthSession {
                Section(String(localized: "watch.activities.section.current_workout", defaultValue: "Current Workout")) {
                    Button {
                        client.send(.init(kind: .resumeCurrentSession, sessionID: client.nowPlaying.sessionID))
                        launcher.armAutoOpenControls()
                        client.requestState()
                    } label: {
                        Label(
                            String(localized: "watch.activities.action.resume_workout", defaultValue: "Resume Workout"),
                            systemImage: "arrow.clockwise.circle.fill"
                        )
                    }
                    .disabled(!client.canSendCommands)

                    Button {
                        launcher.openNowPlaying()
                    } label: {
                        Label(
                            String(localized: "watch.activities.action.open_active_session", defaultValue: "Open Active Session"),
                            systemImage: "figure.strengthtraining.traditional"
                        )
                    }
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

            if !client.canSendCommands {
                Section {
                    Text(String(localized: "watch.activities.status.phone_unavailable", defaultValue: "Phone unavailable"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if !client.isReachable {
                Section {
                    Text(
                        String(
                            localized: "watch.activities.status.phone_closed",
                            defaultValue: "Phone app closed — commands may take a moment"
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle(String(localized: "watch.activities.title", defaultValue: "Workout"))
        .onAppear { client.requestState() }
        .onChange(of: client.nowPlaying.isActiveSession) { _, isActive in
            launcher.consumeAutoOpenIfPossible(hasActiveSession: isActive)
        }
    }
}
