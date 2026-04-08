import SwiftUI
import SwiftData

struct TrackedActivityStartView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(TrackedActivityHealthPreferences.autoSaveCompletedActivitiesKey)
    private var autoSaveToAppleHealth = false

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
            Section(String(localized: "activities.start.section.activity", defaultValue: "Activity")) {
                Picker(String(localized: "activities.start.type", defaultValue: "Type"), selection: $selectedKind) {
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

                Picker(String(localized: "activities.start.environment", defaultValue: "Environment"), selection: $selectedEnvironment) {
                    Text(ActivityEnvironment.indoor.displayName).tag(ActivityEnvironment.indoor)
                    Text(ActivityEnvironment.outdoor.displayName).tag(ActivityEnvironment.outdoor)
                    Text(ActivityEnvironment.unspecified.displayName).tag(ActivityEnvironment.unspecified)
                }
                .onChange(of: selectedEnvironment) { _, _ in
                    environmentWasEdited = true
                }
            }

            Section(String(localized: "activities.health.title", defaultValue: "Apple Health")) {
                HStack {
                    Text(String(localized: "common.status", defaultValue: "Status"))
                    Spacer()
                    Text(healthKitAuthorizationService.state.title)
                        .foregroundStyle(healthStatusColor)
                }

                HStack {
                    Text(String(localized: "activities.start.auto_save", defaultValue: "Auto-save"))
                    Spacer()
                    Text(autoSaveToAppleHealth ? String(localized: "common.on", defaultValue: "On") : String(localized: "common.off", defaultValue: "Off"))
                        .foregroundStyle(.secondary)
                }

                Text(healthStatusExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(String(localized: "activities.summary.notes.section", defaultValue: "Notes")) {
                TextField(String(localized: "activities.summary.notes.placeholder", defaultValue: "Optional notes"), text: $notes, axis: .vertical)
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
        .navigationTitle(String(localized: "activities.start.title", defaultValue: "Start activity"))
        .alert(String(localized: "activities.start.error.title", defaultValue: "Could not start activity"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? String(localized: "common.unknown_error", defaultValue: "Unknown error"))
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
            return healthKitAuthorizationService.routeState == .denied ? .orange : .green
        case .denied:
            return .orange
        case .notRequested, .unavailable:
            return .secondary
        }
    }

    private var healthStatusExplanation: String {
        if selectedEnvironment == .outdoor && selectedKind.supportsDistance {
            if autoSaveToAppleHealth {
                return String(
                    localized: "activities.start.health.auto_save_explanation.outdoor",
                    defaultValue: "Completed sessions try to save automatically to Apple Health when permission is available. Outdoor route points can still be captured locally even if Apple Health route access still needs attention."
                )
            }
            return String(
                localized: "activities.start.health.manual_explanation.outdoor",
                defaultValue: "You can save completed tracked activities to Apple Health later from the summary. Outdoor route points are still captured locally first, then attached only when Apple Health route access is ready."
            )
        }

        if autoSaveToAppleHealth {
            return String(localized: "activities.start.health.auto_save_explanation", defaultValue: "Completed sessions try to save automatically to Apple Health when permission is available. If a save fails, you can still retry later from the summary.")
        }
        return String(localized: "activities.start.health.manual_explanation", defaultValue: "You can start tracked activities even without Apple Health access. Completed sessions can be saved to Apple Health later from the finish summary.")
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
