import SwiftUI

struct EquipmentPickerScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Equipment",
                systemImage: "wrench.and.screwdriver",
                description: Text("Next: multi-select equipment and persist to profile.")
            )
            .navigationTitle("Equipment")
        }
    }
}
