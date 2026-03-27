import SwiftUI

struct TrackingStylePickerSheet: View {
    let exerciseName: String
    @Binding var selection: ExerciseTrackingStyle
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(AppFormatting.localizedFormat("Track %@ as", exerciseName)) {
                    Picker(AppFormatting.localized("Style"), selection: $selection) {
                        ForEach(ExerciseTrackingStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                }
            }
            .navigationTitle(AppFormatting.localized("Tracking"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppFormatting.localized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppFormatting.localized("Add")) {
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
    }
}
