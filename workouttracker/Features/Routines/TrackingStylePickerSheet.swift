import SwiftUI

struct TrackingStylePickerSheet: View {
    let exerciseName: String
    @Binding var selection: ExerciseTrackingStyle
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Track \(exerciseName) as") {
                    Picker("Style", selection: $selection) {
                        ForEach(ExerciseTrackingStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                }
            }
            .navigationTitle("Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
    }
}
