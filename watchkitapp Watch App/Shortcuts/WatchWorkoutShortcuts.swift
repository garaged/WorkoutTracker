import SwiftUI

struct WatchWorkoutShortcutsView: View {
    @ObservedObject var client: WatchConnectivityClient
    @ObservedObject var launcher: WatchRouteLauncher

    var body: some View {
        List {
            if client.nowPlaying.isActiveSession {
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

            Section("Quick Start") {
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
