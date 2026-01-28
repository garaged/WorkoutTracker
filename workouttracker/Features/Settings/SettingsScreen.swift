import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        List {
            Section("About") {
                LabeledContent("App", value: "Workout Tracker")
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
            }

            Section("Appearance") {
                Text("Add theme / units / preferences here later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
