import SwiftUI
import UIKit
import SwiftData

struct TrackedActivityFinishSummaryView: View {
    let sessionID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage(TrackedActivityHealthPreferences.autoSaveCompletedActivitiesKey)
    private var autoSaveToAppleHealth = false

    @State private var session: TrackedActivitySession?

    @State private var distanceKilometersText = ""
    @State private var activeEnergyText = ""
    @State private var stepCountText = ""
    @State private var notes = ""
    @State private var didLoadFields = false
    @State private var errorMessage: String?
    @State private var saveConfirmationVisible = false
    @State private var isExporting = false
    @State private var healthExportMessage: String?
    @State private var isShowingDeleteConfirmation = false
    @State private var showAppleHealthDetails = false
    @State private var didAttemptDeferredAutoSave = false

    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()

    private let recorder = TrackedActivityRecorder()
    private let summaryBuilder = TrackedActivitySummaryBuilder()
    private let exportCoordinator = TrackedActivityHealthExportCoordinator()

    var body: some View {
        Group {
            if let session {
                Form {
                    Section(String(localized: "activities.summary.section", defaultValue: "Summary")) {
                        let summaryMetrics = summaryBuilder.metrics(for: session.summary).filter { $0.kind != .state }
                        if summaryMetrics.isEmpty {
                            Text(String(localized: "activities.summary.low_data", defaultValue: "This activity has low data so the summary only shows the metrics that were actually recorded."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(summaryMetrics) { metric in
                                LabeledContent(metric.title, value: metric.value)
                            }
                        }
                    }

                    if session.activityKind.supportsDistance || session.activityKind.supportsSteps || session.activityKind == .yoga {
                        Section(String(localized: "activities.summary.refine_metrics.section", defaultValue: "Refine metrics")) {
                            if session.activityKind.supportsDistance {
                                TextField(
                                    String(localized: "activities.summary.refine_metrics.distance_km", defaultValue: "Distance (km)"),
                                    text: $distanceKilometersText
                                )
                                .keyboardType(.decimalPad)
                            }

                            TextField(
                                String(localized: "activities.summary.refine_metrics.active_energy", defaultValue: "Active energy (kcal)"),
                                text: $activeEnergyText
                            )
                            .keyboardType(.decimalPad)

                            if session.activityKind.supportsSteps {
                                TextField(
                                    String(localized: "activities.summary.refine_metrics.steps", defaultValue: "Steps"),
                                    text: $stepCountText
                                )
                                .keyboardType(.numberPad)
                            }
                        }
                    }

                    Section(String(localized: "activities.summary.notes.section", defaultValue: "Notes")) {
                        TextField(
                            String(localized: "activities.summary.notes.placeholder", defaultValue: "Optional notes"),
                            text: $notes,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                    }

                    Section {
                        Button(String(localized: "activities.summary.save_changes", defaultValue: "Save summary changes")) {
                            save(session)
                        }
                        .buttonStyle(.borderedProminent)

                        if saveConfirmationVisible {
                            Text(String(localized: "common.saved", defaultValue: "Saved"))
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }

                    appleHealthSection(for: session)
                }
                .navigationTitle(String(localized: "activities.summary.title", defaultValue: "Summary"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if session.allowsLocalDeletion {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .destructive) {
                                isShowingDeleteConfirmation = true
                            } label: {
                                Label(session.localDeleteActionTitle, systemImage: "trash")
                            }
                            .accessibilityIdentifier("trackedActivity.deleteButton")
                        }
                    }
                }
                .accessibilityIdentifier("TrackedActivity.FinishSummary.Screen")
                .confirmationDialog(
                    session.localDeleteTitle,
                    isPresented: $isShowingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(session.localDeleteActionTitle, role: .destructive) {
                        delete(session)
                    }
                    Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
                } message: {
                    Text(session.localDeleteMessage)
                }
                .alert(
                    String(localized: "activities.summary.save_error.title", defaultValue: "Could not save summary"),
                    isPresented: Binding(
                        get: { errorMessage != nil },
                        set: { if !$0 { errorMessage = nil } }
                    )
                ) {
                    Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {
                        errorMessage = nil
                    }
                } message: {
                    Text(errorMessage ?? String(localized: "common.unknown_error", defaultValue: "Unknown error"))
                }
            } else {
                ContentUnavailableView(
                    String(localized: "activities.summary.unavailable.title", defaultValue: "Summary unavailable"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(localized: "activities.summary.unavailable.message", defaultValue: "This tracked activity could not be loaded."))
                )
            }
        }
        .task(id: sessionID) {
            reloadSession()
            healthKitAuthorizationService.refresh()
            await attemptDeferredAutoSaveIfNeeded()
        }
    }

    @ViewBuilder
    private func appleHealthSection(for session: TrackedActivitySession) -> some View {
        Section(String(localized: "activities.health.title", defaultValue: "Apple Health")) {
            LabeledContent(
                String(localized: "activities.health.workout_save_state", defaultValue: "Workout save state"),
                value: session.healthKitExportDisplayName
            )

            Button {
                showAppleHealthDetails.toggle()
                if showAppleHealthDetails {
                    healthKitAuthorizationService.refresh()
                }
            } label: {
                Text(
                    showAppleHealthDetails
                    ? String(localized: "activities.health.hide_details", defaultValue: "Hide Apple Health details")
                    : String(localized: "activities.health.show_details", defaultValue: "Show Apple Health details")
                )
            }
            .buttonStyle(.bordered)

            if showAppleHealthDetails {
                LabeledContent(
                    String(localized: "activities.health.permission", defaultValue: "Permission"),
                    value: healthKitAuthorizationService.state.title
                )

                if session.environment == .outdoor && session.activityKind.supportsDistance {
                    LabeledContent(
                        String(localized: "activities.health.captured_route", defaultValue: "Captured route"),
                        value: session.capturedRouteDisplayValue
                    )
                    LabeledContent(
                        String(localized: "activities.health.route_attachment", defaultValue: "Route attachment"),
                        value: session.routeAttachmentReadinessValue(using: healthKitAuthorizationService)
                    )
                }

                Text(session.healthKitExportHelperText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(healthKitAuthorizationService.statusSummaryMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if session.environment == .outdoor && session.activityKind.supportsDistance {
                    Text(session.routeAttachmentReadinessMessage(using: healthKitAuthorizationService))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(localized: "activities.health.route_requirement", defaultValue: "Outdoor routes require Apple Health access for workout routes and location while using the app during the activity."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let recoveryText = session.healthKitExportRecoveryText {
                    Text(recoveryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let healthExportMessage {
                    Text(healthExportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if session.healthKitExportState != .exported || session.hasLocalChangesSinceHealthKitExport {
                    Button {
                        Task { await exportToHealth(session) }
                    } label: {
                        if isExporting {
                            Label(
                                String(localized: "activities.health.saving", defaultValue: "Saving to Apple Health…"),
                                systemImage: "heart.text.square"
                            )
                        } else {
                            Label(
                                String(localized: "activities.health.save", defaultValue: "Save to Apple Health"),
                                systemImage: "heart.text.square"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.white)
                    .disabled(isExporting || session.lifecycleState != .completed)
                    .accessibilityIdentifier("trackedActivity.exportToHealthKitButton")
                }

                switch healthKitAuthorizationService.state {
                case .unavailable:
                    EmptyView()

                case .notRequested:
                    Button(String(localized: "activities.health.enable", defaultValue: "Enable Apple Health")) {
                        Task { await requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("trackedActivity.enableHealthKitButton")

                case .denied:
                    Button(String(localized: "common.open_settings", defaultValue: "Open Settings")) {
                        openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("trackedActivity.openHealthSettingsButton")

                case .authorized:
                    if session.environment == .outdoor,
                       session.activityKind.supportsDistance,
                       let actionTitle = healthKitAuthorizationService.routePermissionActionTitle {
                        Button(actionTitle) {
                            switch healthKitAuthorizationService.routePermissionAction {
                            case .requestAuthorization:
                                Task { await requestAuthorization() }
                            case .openSettings:
                                openSystemSettings()
                            case nil:
                                break
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func reloadSession() {
        let targetSessionID = sessionID
        let descriptor = FetchDescriptor<TrackedActivitySession>(
            predicate: #Predicate<TrackedActivitySession> { session in
                session.id == targetSessionID
            },
            sortBy: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)]
        )

        do {
            let loaded = try modelContext.fetch(descriptor).first
            session = loaded
            if let loaded {
                loadFieldsIfNeeded(from: loaded)
            }
        } catch {
            session = nil
            errorMessage = error.localizedDescription
        }
    }

    private func attemptDeferredAutoSaveIfNeeded() async {
        guard !didAttemptDeferredAutoSave else { return }
        guard autoSaveToAppleHealth else { return }
        guard let session else { return }
        guard session.lifecycleState == .completed else { return }
                guard !isExporting else { return }
        guard session.healthKitExportState != .exported || session.hasLocalChangesSinceHealthKitExport else { return }

        didAttemptDeferredAutoSave = true
        isExporting = true
        defer { isExporting = false }

        do {
            try? await Task.sleep(nanoseconds: 300_000_000)
            healthKitAuthorizationService.refresh()
            healthExportMessage = try await exportCoordinator.export(
                session,
                trigger: .automatic,
                context: modelContext
            )
            reloadSession()
            healthKitAuthorizationService.refresh()
        } catch {
            healthExportMessage = error.localizedDescription
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
            errorMessage = nil
            healthExportMessage = nil
            didAttemptDeferredAutoSave = false
            reloadSession()

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                saveConfirmationVisible = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ session: TrackedActivitySession) {
        do {
            try recorder.delete(session, context: modelContext)
            self.session = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private func parseInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func requestAuthorization() async {
        do {
            _ = try await healthKitAuthorizationService.requestAuthorization()
            healthExportMessage = nil
            healthKitAuthorizationService.refresh()
            reloadSession()
            await attemptDeferredAutoSaveIfNeeded()
        } catch {
            healthExportMessage = error.localizedDescription
        }
    }

    private func exportToHealth(_ session: TrackedActivitySession) async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            healthExportMessage = try await exportCoordinator.export(
                session,
                trigger: .manual,
                context: modelContext
            )
            reloadSession()
            healthKitAuthorizationService.refresh()
        } catch {
            healthExportMessage = error.localizedDescription
        }
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
