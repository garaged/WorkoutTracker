// workouttracker/Features/Settings/PreferencesScreen.swift
import SwiftUI

/// Backwards-compatible entry point.
/// Anything that already navigates to PreferencesScreen will now see the full Settings hub.
struct PreferencesScreen: View {
    var body: some View {
        SettingsScreen()
    }
}
