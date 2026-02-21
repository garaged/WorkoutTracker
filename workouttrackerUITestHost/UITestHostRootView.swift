// File: workouttrackerUITestHost/UITestHostRootView.swift
import SwiftUI
import Combine

struct UITestHostRootView: View {
    private let env = ProcessInfo.processInfo.environment
    private let cal = Calendar.current

    @State private var timelineJump: TimelineJump? = nil

    private struct TimelineJump: Identifiable {
        let id = UUID()
        let day: Date
    }

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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("workouttracker.openTimelineForDate"))) { note in
            guard let date = note.object as? Date else { return }
            timelineJump = TimelineJump(day: cal.startOfDay(for: date))
        }
        .fullScreenCover(item: $timelineJump) { jump in
            NavigationStack {
                DayTimelineEntryScreen(initialDay: jump.day)
            }
        }
    }
}
