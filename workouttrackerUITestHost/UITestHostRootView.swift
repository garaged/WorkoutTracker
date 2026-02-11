// workouttrackerUITestHost/UITestHostRootView.swift
import SwiftUI

struct UITestHostRootView: View {
    private let env = ProcessInfo.processInfo.environment

    var body: some View {
        NavigationStack {
            switch (env["UITESTS_START"] ?? "calendar").lowercased() {
            case "settings":
                SettingsScreen()

            case "home":
                AppRootView()

            // Default to calendar because most UI tests expect it.
            case "calendar", "":
                DayTimelineEntryScreen()

            default:
                DayTimelineEntryScreen()
            }
        }
    }
}
