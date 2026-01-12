import SwiftUI

struct MeasurementsScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Measurements",
                systemImage: "ruler",
                description: Text("Next: body measurements list + add/edit entries.")
            )
            .navigationTitle("Measurements")
        }
    }
}
