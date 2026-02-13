// File: workouttrackerUITestHost/UITestHostRootView.swift
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
            case "calendar", "":
                DayTimelineEntryScreen()
            default:
                DayTimelineEntryScreen()
            }
        }
    }
}
