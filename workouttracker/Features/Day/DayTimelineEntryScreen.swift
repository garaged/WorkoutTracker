import SwiftUI

struct DayTimelineEntryScreen: View {
    private let cal = Calendar.current

    @State private var day: Date = Date()
    @State private var presentedSession: WorkoutSession? = nil

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
        .navigationBarTitleDisplayMode(.inline)
        // ✅ Do NOT hide the system back button. Keeps the chevron consistent across the app.
        .toolbar {
            // ✅ Keep the title compact so trailing buttons don’t get dropped
            ToolbarItem(placement: .principal) {
                Text(dayTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Optional: tap the date to jump to today
                        day = Date()
                    }
            }

            // ✅ Put all day navigation on the right so it doesn’t visually clash with the back chevron
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left.circle")
                }
                .accessibilityLabel("Previous day")

                Button { day = Date() } label: {
                    Image(systemName: isToday ? "calendar.circle" : "calendar.circle.fill")
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
        .sheet(isPresented: $showingEditPlaceholder) {
            PlaceholderSheet(
                title: "Edit Activity",
                message: "Wire onEdit to your real activity editor."
            )
        }
        .sheet(isPresented: $showingCreatePlaceholder) {
            PlaceholderSheet(
                title: "Create Activity",
                message: "Wire onCreateAt/onCreateRange to your create flow."
            )
        }
    }

    private var dayTitle: String {
        // Matches your prior “Tue 27 Jan” style
        day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private func shiftDay(_ delta: Int) {
        day = cal.date(byAdding: .day, value: delta, to: day) ?? day
    }
}

private struct PlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(message).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(16)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
