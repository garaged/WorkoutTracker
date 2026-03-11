import SwiftUI

// File: workouttracker/Features/Routines/RoutineRow/RoutineListItem.swift
//
// Why this update lives here:
// This row is the user's primary entry point from the routines list, so the
// discoverability fix for routine editing belongs here rather than in the
// editor itself.

struct RoutineListItem: View {
    let title: String
    let badgeText: String?

    let onStartNow: () -> Void
    let onScheduleToday: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    init(
        title: String,
        badgeText: String? = nil,
        onStartNow: @escaping () -> Void,
        onScheduleToday: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.title = title
        self.badgeText = badgeText
        self.onStartNow = onStartNow
        self.onScheduleToday = onScheduleToday
        self.onEdit = onEdit
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
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the routine editor")
        .accessibilityAction(named: "Edit routine", onEdit)
        .contextMenu {
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            Button(action: onStartNow) { Label("Start now", systemImage: "play.fill") }
            Button(action: onScheduleToday) { Label("Schedule for today", systemImage: "calendar.badge.plus") }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onStartNow) { Label("Start", systemImage: "play.fill") }
                .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                .tint(.blue)

            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }
}
