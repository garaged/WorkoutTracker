import SwiftUI
import SwiftData

struct QuickStartLauncherScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var launchedSessionID: UUID?
    @State private var showConflict = false
    @State private var errorMessage: String?

    private let recorder = QuickStartRecorder()
    private let clockSource = QuickStartClockSource()

    var body: some View {
        List {
            Section {
                ForEach(QuickStartStyle.defaults) { style in
                    startButton(for: style)
                }
            } header: {
                Text(String(localized: "quickstart.defaults.title", defaultValue: "Quick choices"))
            } footer: {
                Text(String(localized: "quickstart.defaults.help", defaultValue: "Starting only records active time. Reps, weight, distance, calories, and program progress stay empty unless you add them elsewhere."))
            }

            Section {
                DisclosureGroup(String(localized: "quickstart.more.title", defaultValue: "More styles")) {
                    ForEach(QuickStartStyle.allCases.filter { !QuickStartStyle.defaults.contains($0) }) { style in
                        startButton(for: style)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "quickstart.title", defaultValue: "Start a timer"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $launchedSessionID) { sessionID in
            QuickStartSessionScreen(sessionID: sessionID)
        }
        .alert(
            String(localized: "quickstart.conflict.title", defaultValue: "A workout is already active"),
            isPresented: $showConflict
        ) {
            Button(String(localized: "quickstart.conflict.resume", defaultValue: "Resume existing")) {
                dismiss()
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "quickstart.conflict.message", defaultValue: "Return to Today to resume or finish the active workout before starting another timer."))
        }
        .alert(
            String(localized: "quickstart.error.title", defaultValue: "Could not start timer"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "common.unknown_error", defaultValue: "Unknown error"))
        }
        .accessibilityIdentifier("QuickStart.Launcher.Screen")
    }

    private func startButton(for style: QuickStartStyle) -> some View {
        Button {
            start(style)
        } label: {
            Label(styleTitle(style), systemImage: styleIcon(style))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("QuickStart.Style.\(style.rawValue)")
        .accessibilityLabel(String(localized: "quickstart.start.accessibility", defaultValue: "Start \(styleTitle(style))"))
    }

    private func start(_ style: QuickStartStyle) {
        do {
            let session = try recorder.start(
                style: style,
                id: UUID(),
                at: clockSource.sample(),
                context: modelContext
            )
            launchedSessionID = session.id
        } catch QuickStartRecorder.RecordingError.activeSessionConflict(_) {
            showConflict = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

func quickStartStyleTitle(_ style: QuickStartStyle?) -> String {
    guard let style else {
        return String(localized: "quickstart.style.other", defaultValue: "Other activity")
    }
    return switch style {
    case .cardio: String(localized: "quickstart.style.cardio", defaultValue: "Cardio")
    case .strengthWeights: String(localized: "quickstart.style.strength_weights", defaultValue: "Weights and machines")
    case .bodyweightFunctional: String(localized: "quickstart.style.bodyweight_functional", defaultValue: "Bodyweight and functional")
    case .hiit: String(localized: "quickstart.style.hiit", defaultValue: "HIIT")
    case .danceFitness: String(localized: "quickstart.style.dance_fitness", defaultValue: "Dance fitness")
    case .yoga: String(localized: "quickstart.style.yoga", defaultValue: "Yoga")
    case .pilates: String(localized: "quickstart.style.pilates", defaultValue: "Pilates")
    case .mobilityStretching: String(localized: "quickstart.style.mobility_stretching", defaultValue: "Mobility and stretching")
    case .other: String(localized: "quickstart.style.other", defaultValue: "Other activity")
    }
}

private func styleTitle(_ style: QuickStartStyle) -> String {
    return quickStartStyleTitle(style)
}

private func styleIcon(_ style: QuickStartStyle) -> String {
    return switch style {
    case .cardio: "heart.fill"
    case .strengthWeights: "dumbbell.fill"
    case .bodyweightFunctional: "figure.strengthtraining.traditional"
    case .hiit: "bolt.fill"
    case .danceFitness: "figure.dance"
    case .yoga: "figure.yoga"
    case .pilates: "figure.pilates"
    case .mobilityStretching: "figure.cooldown"
    case .other: "timer"
    }
}
