// workouttracker/Features/Settings/SettingsToolbarLink.swift
import SwiftUI

/// Drop-in "gear" link you can add to any screen's `.toolbar { ... }`.
struct SettingsToolbarLink: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                SettingsScreen()
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
            }
        }
    }
}
