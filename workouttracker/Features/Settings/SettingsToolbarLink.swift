// workouttracker/Features/Settings/SettingsToolbarLink.swift
import SwiftUI

/// Drop-in gear link you can add to any screen's `.toolbar { ... }`.
struct SettingsToolbarLink: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                SettingsScreen()
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityDecorative()
            }
            .accessibilityIconControl(
                label: AccessibilityLabels.Buttons.settings,
                hint: AccessibilityLabels.Buttons.settingsHint,
                identifier: UIAccessibilityIdentifiers.Settings.toolbarLink
            )
        }
    }
}
