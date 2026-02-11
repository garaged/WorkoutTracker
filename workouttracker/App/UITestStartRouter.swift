import SwiftUI

// workouttracker/App/UITestStartRouter.swift
struct UITestStartRouter: View {
    private let start: String

    init(start: String = ProcessInfo.processInfo.environment["UITESTS_START"] ?? "") {
        self.start = start.lowercased()
    }

    var body: some View {
        switch start {
        case "calendar":
            NavigationStack { DayTimelineEntryScreen() }
        case "settings":
            NavigationStack { SettingsScreen() }
        case "home", "":
            AppRootView()
        default:
            AppRootView()
        }
    }
}
