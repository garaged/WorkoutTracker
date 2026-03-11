import SwiftUI

// File: workouttracker/Features/Routines/RoutineRow/RoutineRow.swift
//
// Why this update lives here:
// This is the shared row chrome for routines, so the visual cue that the row
// can be opened for editing belongs here.

struct RoutineRow: View {
    let title: String
    let onStartNow: () -> Void
    let onScheduleToday: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.thinMaterial)
                    .frame(width: 36, height: 36)

                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Text("Tap to edit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Button(action: onScheduleToday) {
                Image(systemName: "calendar.badge.plus")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Schedule for today")

            Button(action: onStartNow) {
                Image(systemName: "play.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Start now")
        }
        .padding(.vertical, 4)
    }
}
