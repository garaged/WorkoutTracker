// File: workouttracker/Features/Day/DayTimelineEntryScreen.swift
//
// This is the "Calendar entry" wrapper pushed from Home.
// It owns navigation to WorkoutSessionScreen (so Summary works when launched from Home)
// and provides a compact, consistent header:
// - Back chevron stays on the left (system)
// - Day navigation (prev / go-to-today / next) stays on the right

import SwiftUI

struct DayTimelineEntryScreen: View {
    private let cal = Calendar.current

    @State private var day: Date = Date()
    @State private var presentedSession: WorkoutSession? = nil

    // Placeholders so the callbacks are satisfied.
    // Later: wire to your real activity editor / creator flows.
    @State private var showingEditPlaceholder = false
    @State private var showingCreatePlaceholder = false

    private var dayStart: Date { cal.startOfDay(for: day) }
    private var isToday: Bool { cal.isDateInToday(day) }

    var body: some View {
        DayTimelineScreen(
            day: dayStart,
            presentedSession: $presentedSession,
            onEdit: { _ in showingEditPlaceholder = true },
            onCreateAt: { _, _ in showingCreatePlaceholder = true },
            onCreateRange: { _, _, _ in showingCreatePlaceholder = true }
        )
        // ✅ Critical: without this, `openSession(...)` sets the binding but nothing navigates.
        .navigationDestination(item: $presentedSession) { s in
            WorkoutSessionScreen(session: s)
        }
        .navigationBarTitleDisplayMode(.inline)
        // ✅ Do NOT hide the system back button. Keeps the chevron consistent across the app.
        .toolbar { headerToolbar }
        .sheet(isPresented: $showingEditPlaceholder) {
            PlaceholderSheet(
                title: "Edit Activity",
                message: "This entry screen is wired. Next, connect onEdit to your real activity editor."
            )
        }
        .sheet(isPresented: $showingCreatePlaceholder) {
            PlaceholderSheet(
                title: "Create Activity",
                message: "This entry screen is wired. Next, connect onCreateAt/onCreateRange to your real create flow."
            )
        }
    }

    // Matches your prior “Tue 27 Jan” style
    private var dayTitle: String {
        day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var headerToolbar: some ToolbarContent {
        Group {
            // Compact title in the center so trailing buttons don’t get dropped
            ToolbarItem(placement: .principal) {
                Text(dayTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Optional: tap the date to jump to today (keeps the "go to today" feature alive)
                        day = Date()
                    }
            }

            // Keep all day navigation on the right to avoid visually clashing with the back chevron.
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left.circle")
                }
                .accessibilityLabel("Previous day")

                Button { day = Date() } label: {
                    Image(systemName: "calendar")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isToday ? Color.secondary : Color.accentColor)
                }
                .disabled(isToday)
                .accessibilityLabel("Go to today")

                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right.circle")
                }
                .accessibilityLabel("Next day")
            }
        }
    }

    private func shiftDay(_ delta: Int) {
        day = cal.date(byAdding: .day, value: delta, to: day) ?? day
    }
}

private struct PlaceholderSheet: View {
    let title: String
    let message: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("OK") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
