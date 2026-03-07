import SwiftUI

/// Drop-in Settings form section.
///
/// Why this lives in `Features/Settings`:
/// - It is purely presentation logic for the Settings hub.
/// - The actual persisted preference still lives in `UserPreferences`.
public struct ExerciseIllustrationSetPickerSection: View {
    @StateObject private var prefs = UserPreferences.shared

    public init() {}

    public var body: some View {
        Section("Exercise Images") {
            Picker("Illustration Set", selection: illustrationSetBinding) {
                ForEach(ExerciseIllustrationSet.allCases) { set in
                    Text(set.displayName).tag(set)
                }
            }
            .accessibilityIdentifier("settings.exerciseIllustrationSetPicker")

            Text("Changes which bundled exercise art set is shown for seeded and catalog exercises. Default uses the neutral dummy artwork.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var illustrationSetBinding: Binding<ExerciseIllustrationSet> {
        Binding(
            get: { prefs.exerciseIllustrationSet },
            set: { prefs.exerciseIllustrationSet = $0 }
        )
    }
}
