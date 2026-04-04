import SwiftUI
import SwiftData

struct TrackedActivityStartView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedKind: TrackedActivityKind = .walking
    @State private var selectedEnvironment: ActivityEnvironment = TrackedActivityKind.walking.defaultEnvironment
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var startedSessionID: UUID?
    @State private var environmentWasEdited = false

    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()

    private let recorder = TrackedActivityRecorder()

    var body: some View {
        Form {
            Section("Activity") {
                Picker("Type", selection: $selectedKind) {
                    ForEach(TrackedActivityKind.allCases, id: \.self) { kind in
                        Label(kind.displayName, systemImage: kind.systemImage)
                            .tag(kind)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedKind) { _, newValue in
                    if !environmentWasEdited {
                        selectedEnvironment = newValue.defaultEnvironment
                    }
                }

                Picker("Environment", selection: $selectedEnvironment) {
                    Text(ActivityEnvironment.indoor.displayName).tag(ActivityEnvironment.indoor)
                    Text(ActivityEnvironment.outdoor.displayName).tag(ActivityEnvironment.outdoor)
                    Text(ActivityEnvironment.unspecified.displayName).tag(ActivityEnvironment.unspecified)
                }
                .onChange(of: selectedEnvironment) { _, _ in
                    environmentWasEdited = true
                }
            }

            Section("Apple Health") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(healthKitAuthorizationService.state.title)
                        .foregroundStyle(healthStatusColor)
                }

                Text("You can start tracked activities even without Apple Health access. Completed sessions can be saved to Apple Health later from the finish summary.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Text(selectedKind.helperText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    start()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedKind.systemImage)
                            .imageScale(.medium)

                        Text(selectedKind.startVerb)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Start activity")
        .alert("Could not start activity", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .navigationDestination(isPresented: Binding(
            get: { startedSessionID != nil },
            set: { if !$0 { startedSessionID = nil } }
        )) {
            if let startedSessionID {
                TrackedActivitySessionScreen(sessionID: startedSessionID)
            }
        }
        .task {
            healthKitAuthorizationService.refresh()
        }
    }

    private var healthStatusColor: Color {
        switch healthKitAuthorizationService.state {
        case .authorized:
            return .green
        case .denied:
            return .orange
        case .notRequested, .unavailable:
            return .secondary
        }
    }

    private func start() {
        do {
            let session = try recorder.createSession(
                activityKind: selectedKind,
                environment: selectedEnvironment,
                notes: notes,
                context: modelContext
            )
            WorkoutRemoteControlRouter.shared.focusTrackedActivity(sessionID: session.id)
            WorkoutRemoteControlRouter.shared.refreshNowPlaying()
            startedSessionID = session.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
