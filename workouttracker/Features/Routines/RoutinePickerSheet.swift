import SwiftUI

/// Attach a routine to a template activity.
/// Wire this by injecting your routines list + an onPick callback.
struct RoutinePickerSheet: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Pick a Routine",
                systemImage: "dumbbell",
                description: Text("Next: list routines and return selection.")
            )
            .navigationTitle("Pick Routine")
        }
    }
}
