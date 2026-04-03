import SwiftUI
import UIKit

struct HealthPermissionsView: View {
    @StateObject private var authorizationService = HealthKitAuthorizationService()

    var body: some View {
        List {
            Section(String(localized: "health.permissions.section.status", defaultValue: "Status")) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "health.permissions.row.apple_health", defaultValue: "Apple Health"))
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

            Section(String(localized: "health.permissions.section.saves", defaultValue: "What WorkoutTracker saves")) {
                Label(
                    String(localized: "health.permissions.saves.completed_workouts", defaultValue: "Completed walk, run, hike, and yoga workouts"),
                    systemImage: "checkmark.circle"
                )
                Label(
                    String(localized: "health.permissions.saves.start_end_time", defaultValue: "Workout start and end time"),
                    systemImage: "clock"
                )
                Label(
                    String(localized: "health.permissions.saves.distance_energy", defaultValue: "Distance and active energy when you add them"),
                    systemImage: "figure.walk.motion"
                )
                Label(
                    String(localized: "health.permissions.saves.route_data", defaultValue: "Eligible outdoor route data when location access is available"),
                    systemImage: "map"
                )

                Text(
                    String(
                        localized: "health.permissions.saves.footer",
                        defaultValue: "This release writes completed tracked activities to Apple Health. Outdoor walks, runs, and hikes can also include route data when you allow location while using the app."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section(String(localized: "health.permissions.section.location", defaultValue: "Location for outdoor routes")) {
                Text(
                    String(
                        localized: "health.permissions.location.body",
                        defaultValue: "Outdoor route capture uses your location while the tracked activity screen is open. If location access is denied, the workout can still be saved to Apple Health without a route."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Button(String(localized: "health.permissions.action.open_settings", defaultValue: "Open Settings")) {
                    openSystemSettings()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("healthPermissions.openSettingsButton")
            }

            Section {
                switch authorizationService.state {
                case .notRequested:
                    Button(String(localized: "health.permissions.action.enable", defaultValue: "Enable Apple Health")) {
                        Task { await requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("healthPermissions.enableButton")

                case .denied:
                    Button(String(localized: "health.permissions.action.open_settings", defaultValue: "Open Settings")) {
                        openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("healthPermissions.openHealthSettingsButton")

                case .authorized:
                    Button(String(localized: "health.permissions.action.refresh", defaultValue: "Refresh status")) {
                        authorizationService.refresh()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("healthPermissions.refreshButton")

                case .unavailable:
                    EmptyView()
                }
            }
        }
        .navigationTitle(String(localized: "health.permissions.title", defaultValue: "Apple Health"))
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
