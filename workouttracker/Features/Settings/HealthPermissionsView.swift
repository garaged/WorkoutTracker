import SwiftUI
import UIKit

struct HealthPermissionsView: View {
    @StateObject private var authorizationService = HealthKitAuthorizationService()

    var body: some View {
        List {
            Section("Status") {
                HStack(alignment: .firstTextBaseline) {
                    Text("Apple Health")
                    Spacer()
                    Text(authorizationService.state.title)
                        .foregroundStyle(statusColor)
                        .font(.subheadline.weight(.semibold))
                }

                Text(authorizationService.state.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("What WorkoutTracker saves") {
                Label("Completed walk, run, hike, and yoga workouts", systemImage: "checkmark.circle")
                Label("Workout start and end time", systemImage: "clock")
                Label("Distance and active energy when you add them", systemImage: "figure.walk.motion")

                Text("This release only writes completed tracked activities to Apple Health. It does not import existing Health workouts yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                switch authorizationService.state {
                case .notRequested:
                    Button("Enable Apple Health") {
                        Task { await requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("healthPermissions.enableButton")

                case .denied:
                    Button("Open Settings") {
                        openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("healthPermissions.openSettingsButton")

                case .authorized:
                    Button("Refresh status") {
                        authorizationService.refresh()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("healthPermissions.refreshButton")

                case .unavailable:
                    EmptyView()
                }
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            authorizationService.refresh()
        }
    }

    private var statusColor: Color {
        switch authorizationService.state {
        case .authorized:
            return .green
        case .denied:
            return .orange
        case .notRequested:
            return .secondary
        case .unavailable:
            return .secondary
        }
    }

    private func requestAuthorization() async {
        do {
            _ = try await authorizationService.requestAuthorization()
        } catch {
            authorizationService.refresh()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
