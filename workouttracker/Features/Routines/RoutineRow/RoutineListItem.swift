import SwiftUI

struct RoutineListItem: View {
    let title: String
    let onStartNow: () -> Void
    let onScheduleToday: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        RoutineRow(
            title: title,
            onStartNow: onStartNow,
            onScheduleToday: onScheduleToday
        )
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
