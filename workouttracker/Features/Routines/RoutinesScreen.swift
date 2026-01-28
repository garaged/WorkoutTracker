import SwiftUI

struct RoutinesScreen: View {
    var body: some View {
        List {
            Section {
                ActionRow(
                    title: "My Routines",
                    subtitle: "View and edit your routines",
                    systemImage: "list.bullet.rectangle.portrait"
                )

                ActionRow(
                    title: "Create Routine",
                    subtitle: "Build a new plan",
                    systemImage: "plus.circle.fill"
                )
            }

            Section("Notes") {
                Text("This is the routines hub. Next step is to replace rows with NavigationLinks to your real routine list/detail screens.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Routines")
    }
}
