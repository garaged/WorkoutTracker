import SwiftUI

private struct WatchTrackedActivityShortcut: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let activityKindRaw: String
    let environmentRaw: String
}

private let trackedActivityShortcuts: [WatchTrackedActivityShortcut] = [
    .init(id: "walking", title: "Walk", systemImage: "figure.walk", activityKindRaw: "walking", environmentRaw: "outdoor"),
    .init(id: "running", title: "Run", systemImage: "figure.run", activityKindRaw: "running", environmentRaw: "outdoor"),
    .init(id: "hiking", title: "Hike", systemImage: "figure.hiking", activityKindRaw: "hiking", environmentRaw: "outdoor"),
    .init(id: "yoga", title: "Yoga", systemImage: "figure.yoga", activityKindRaw: "yoga", environmentRaw: "indoor")
]

struct WatchWorkoutShortcutsView: View {
    @ObservedObject var client: WatchConnectivityClient
    @ObservedObject var launcher: WatchRouteLauncher

    var body: some View {
        List {
            if client.nowPlaying.isActiveSession, client.nowPlaying.isTrackedActivitySession {
                Section("Current Activity") {
                    Button {
                        launcher.armAutoOpenControls()
                        client.send(.init(kind: .resumeCurrentTrackedActivity, sessionID: client.nowPlaying.sessionID))
                        client.requestState()
                    } label: {
                        Label(client.nowPlaying.isPaused ? "Resume Activity" : "Open Activity", systemImage: client.nowPlaying.isPaused ? "play.circle.fill" : "figure.walk.motion")
                    }
                    .disabled(!client.canSendCommands)

                    Button {
                        launcher.openNowPlaying()
                    } label: {
                        Label("Open Controls", systemImage: "applewatch.watchface")
                    }
                }
            }

            if client.nowPlaying.isActiveSession, client.nowPlaying.isStrengthSession {
                Section("Current Workout") {
                    Button {
                        client.send(.init(kind: .resumeCurrentSession, sessionID: client.nowPlaying.sessionID))
                        launcher.armAutoOpenControls()
                        client.requestState()
                    } label: {
                        Label("Resume Workout", systemImage: "arrow.clockwise.circle.fill")
                    }
                    .disabled(!client.canSendCommands)

                    Button {
                        launcher.openNowPlaying()
                    } label: {
                        Label("Open Active Session", systemImage: "figure.strengthtraining.traditional")
                    }
                }
            }

            Section("Start Activity") {
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

            Section("Quick Start Workouts") {
                if client.nowPlaying.quickStartRoutines.isEmpty {
                    Text("No routines yet")
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
                    Text("Phone unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if !client.isReachable {
                Section {
                    Text("Phone app closed — commands may take a moment")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Workout")
        .onAppear { client.requestState() }
        .onChange(of: client.nowPlaying.isActiveSession) { _, isActive in
            launcher.consumeAutoOpenIfPossible(hasActiveSession: isActive)
        }
    }
}
