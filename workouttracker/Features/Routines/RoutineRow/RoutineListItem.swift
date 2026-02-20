import SwiftUI

// File: workouttracker/Features/Routines/RoutineListItem.swift
//
// Patch:
// - Adds an optional `badgeText` so we can show a small "Starter" badge
//   for built-in routines without changing the row layout logic.

struct RoutineListItem: View {
    let title: String
    let badgeText: String?

    let onStartNow: () -> Void
    let onScheduleToday: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    init(
        title: String,
        badgeText: String? = nil,
        onStartNow: @escaping () -> Void,
        onScheduleToday: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.title = title
        self.badgeText = badgeText
        self.onStartNow = onStartNow
        self.onScheduleToday = onScheduleToday
        self.onRename = onRename
        self.onDelete = onDelete
    }

    var body: some View {
        RoutineRow(
            title: title,
            onStartNow: onStartNow,
            onScheduleToday: onScheduleToday
        )
        .overlay(alignment: .topTrailing) {
            if let badgeText {
                StarterBadge(text: badgeText)
                    .padding(.trailing, 8)
                    .padding(.top, 6)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: onStartNow) { Label("Start now", systemImage: "play.fill") }
            Button(action: onScheduleToday) { Label("Schedule for today", systemImage: "calendar.badge.plus") }
            Button(action: onRename) { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onStartNow) { Label("Start", systemImage: "play.fill") }
                .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onRename) { Label("Rename", systemImage: "pencil") }
                .tint(.blue)

            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }
}
