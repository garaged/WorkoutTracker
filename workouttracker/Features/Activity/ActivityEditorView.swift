import SwiftUI
import SwiftData

struct ActivityEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let cal = Calendar.current
    private let activity: Activity?
    private let day: Date
    private let initialStart: Date?
    private let initialEnd: Date?
    private let initialLaneHint: Int?

    @State private var title: String
    @State private var startAt: Date
    @State private var hasEnd: Bool
    @State private var endAt: Date

    init(day: Date, activity: Activity?, initialStart: Date?, initialEnd: Date?, initialLaneHint: Int?) {
        self.day = day
        self.activity = activity
        self.initialStart = initialStart
        self.initialEnd = initialEnd
        self.initialLaneHint = initialLaneHint

        let fallbackStart = ActivityEditorView.defaultStart(for: day)
        let start = activity?.startAt ?? (initialStart ?? fallbackStart)

        let minEnd = cal.date(byAdding: .minute, value: 15, to: start) ?? start
        let proposedEnd =
            activity?.endAt
            ?? initialEnd
            ?? cal.date(byAdding: .minute, value: 30, to: start)!

        let end = max(proposedEnd, minEnd)

        _title = State(initialValue: activity?.title ?? "")
        _startAt = State(initialValue: start)

        // ✅ New activities default to having an end time
        _hasEnd = State(initialValue: activity == nil ? true : (activity?.endAt != nil))

        _endAt = State(initialValue: end)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Title", text: $title)
                }

                Section("Time") {
                    DatePicker("Start", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: startAt) { _, newStart in
                            let minEnd = cal.date(byAdding: .minute, value: 15, to: newStart) ?? newStart
                            if endAt < minEnd {
                                endAt = cal.date(byAdding: .minute, value: 30, to: newStart) ?? minEnd
                            }
                        }

                    Toggle("Set end time", isOn: $hasEnd)

                    if hasEnd {
                        DatePicker("End", selection: $endAt, in: minEndRange..., displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle(activity == nil ? "New Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var minEndRange: Date {
        cal.date(byAdding: .minute, value: 15, to: startAt) ?? startAt
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEnd: Date? = hasEnd ? endAt : nil

        if let activity {
            activity.title = t
            activity.startAt = startAt
            activity.endAt = finalEnd
            // keep existing laneHint unless you later add UI to change it
        } else {
            let lane = max(0, initialLaneHint ?? 0)
            let new = Activity(title: t, startAt: startAt, endAt: finalEnd, laneHint: lane)
            modelContext.insert(new)
        }

        dismiss()
    }

    private static func defaultStart(for day: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return Date() }

        let startOfDay = cal.startOfDay(for: day)
        return cal.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay
    }
}
