import SwiftUI
import UIKit
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
    @State private var isExporting = false
    @State private var healthExportMessage: String?

    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()

    private let recorder = TrackedActivityRecorder()
    private let summaryBuilder = TrackedActivitySummaryBuilder()
    private let exportService = HealthKitWorkoutExportService()

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

                    appleHealthSection(for: session)
                }
                .navigationTitle("Summary")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    loadFieldsIfNeeded(from: session)
                    healthKitAuthorizationService.refresh()
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

    @ViewBuilder
    private func appleHealthSection(for session: TrackedActivitySession) -> some View {
        Section("Apple Health") {
            LabeledContent("Permission", value: healthKitAuthorizationService.state.title)
            LabeledContent("Workout save state", value: session.healthKitExportState.displayName)

            Text(session.healthKitExportState.helperText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(healthKitAuthorizationService.state.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let healthExportMessage {
                Text(healthExportMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch healthKitAuthorizationService.state {
            case .unavailable:
                EmptyView()

            case .notRequested:
                Button("Enable Apple Health") {
                    Task { await requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("trackedActivity.enableHealthKitButton")

            case .denied:
                Button("Open Settings") {
                    openSystemSettings()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("trackedActivity.openHealthSettingsButton")

            case .authorized:
                if session.healthKitExportState == .exported {
                    EmptyView()
                } else {
                    Button {
                        Task { await exportToHealth(session) }
                    } label: {
                        if isExporting {
                            Label("Saving to Apple Health…", systemImage: "heart.text.square")
                        } else {
                            Label("Save to Apple Health", systemImage: "heart.text.square")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExporting || session.lifecycleState != .completed)
                    .accessibilityIdentifier("trackedActivity.exportToHealthKitButton")
                }
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
            if session.healthKitExportState == .failed {
                healthExportMessage = "Summary saved. You can retry saving to Apple Health with the updated values."
            } else if session.healthKitExportState == .exported {
                healthExportMessage = "Summary saved locally. Because this workout was already saved to Apple Health, later edits here do not update the exported Health workout in this release."
            } else {
                healthExportMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestAuthorization() async {
        do {
            _ = try await healthKitAuthorizationService.requestAuthorization()
        } catch {
            healthKitAuthorizationService.refresh()
            errorMessage = error.localizedDescription
        }
    }

    private func exportToHealth(_ session: TrackedActivitySession) async {
        guard !isExporting else { return }
        isExporting = true
        healthExportMessage = nil

        do {
            try recorder.updateHealthKitExportState(for: session, state: .pending, context: modelContext)
            try await exportService.export(session)
            try recorder.updateHealthKitExportState(for: session, state: .exported, context: modelContext)
            healthExportMessage = "Saved to Apple Health."
        } catch let exportError as HealthKitWorkoutExportError {
            let failedState: HealthKitExportState = {
                switch exportError {
                case .healthDataUnavailable:
                    return .notAvailable
                case .permissionDenied, .sessionMustBeCompleted, .sessionDatesUnavailable, .unsupportedActivity:
                    return .failed
                }
            }()
            try? recorder.updateHealthKitExportState(for: session, state: failedState, context: modelContext)
            errorMessage = exportError.localizedDescription
        } catch {
            try? recorder.updateHealthKitExportState(for: session, state: .failed, context: modelContext)
            errorMessage = error.localizedDescription
        }

        healthKitAuthorizationService.refresh()
        isExporting = false
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
