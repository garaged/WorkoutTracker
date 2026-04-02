import SwiftUI
import SwiftData

struct TrackedActivityFinishSummaryView: View {
    let sessionID: UUID

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)])
    private var trackedSessions: [TrackedActivitySession]

    @State private var distanceKilometersText = ""
    @State private var activeEnergyText = ""
    @State private var stepCountText = ""
    @State private var notes = ""
    @State private var didLoadFields = false
    @State private var errorMessage: String?
    @State private var saveConfirmationVisible = false

    private let recorder = TrackedActivityRecorder()
    private let summaryBuilder = TrackedActivitySummaryBuilder()

    private var session: TrackedActivitySession? {
        trackedSessions.first(where: { $0.id == sessionID })
    }

    var body: some View {
        Group {
            if let session {
                Form {
                    Section("Summary") {
                        ForEach(summaryBuilder.metrics(for: session.summary).filter { $0.kind != .state }) { metric in
                            LabeledContent(metric.title, value: metric.value)
                        }
                    }

                    if session.activityKind.supportsDistance || session.activityKind.supportsSteps || session.activityKind == .yoga {
                        Section("Refine metrics") {
                            if session.activityKind.supportsDistance {
                                TextField("Distance (km)", text: $distanceKilometersText)
                                    .keyboardType(.decimalPad)
                            }

                            TextField("Active energy (kcal)", text: $activeEnergyText)
                                .keyboardType(.decimalPad)

                            if session.activityKind.supportsSteps {
                                TextField("Steps", text: $stepCountText)
                                    .keyboardType(.numberPad)
                            }
                        }
                    }

                    Section("Notes") {
                        TextField("Optional notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    Section {
                        Button("Save summary changes") {
                            save(session)
                        }
                        .buttonStyle(.borderedProminent)

                        if saveConfirmationVisible {
                            Text("Saved")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .navigationTitle("Summary")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    loadFieldsIfNeeded(from: session)
                }
                .alert("Could not save summary", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "Unknown error")
                }
            } else {
                ContentUnavailableView(
                    "Summary unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This tracked activity could not be loaded.")
                )
            }
        }
    }

    private func loadFieldsIfNeeded(from session: TrackedActivitySession) {
        guard !didLoadFields else { return }
        didLoadFields = true

        if let distanceMeters = session.distanceMeters, distanceMeters > 0 {
            distanceKilometersText = (distanceMeters / 1_000).formatted(.number.precision(.fractionLength(0...2)))
        }
        if let activeEnergy = session.activeEnergyKilocalories, activeEnergy > 0 {
            activeEnergyText = activeEnergy.formatted(.number.precision(.fractionLength(0...1)))
        }
        if let stepCount = session.stepCount, stepCount > 0 {
            stepCountText = String(stepCount)
        }
        notes = session.notes ?? ""
    }

    private func save(_ session: TrackedActivitySession) {
        do {
            let distanceMeters = parseDouble(distanceKilometersText).map { $0 * 1_000 }
            let activeEnergy = parseDouble(activeEnergyText)
            let steps = parseInt(stepCountText)

            try recorder.updateSummaryValues(
                for: session,
                distanceMeters: distanceMeters,
                activeEnergyKilocalories: activeEnergy,
                stepCount: steps,
                notes: notes,
                context: modelContext
            )
            saveConfirmationVisible = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseDouble(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private func parseInt(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }
}
