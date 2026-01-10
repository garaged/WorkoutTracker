import SwiftUI
import SwiftData

struct ActivityEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let cal = Calendar.current
    private let activity: Activity?
    private let day: Date
    private let initialStart: Date?

    @State private var title: String
    @State private var startAt: Date
    @State private var hasEnd: Bool
    @State private var endAt: Date

    init(day: Date, activity: Activity?, initialStart: Date?) {
        self.day = day
        self.activity = activity
        self.initialStart = initialStart

        let fallback = ActivityEditorView.defaultStart(for: day)
        let start = activity?.startAt ?? (initialStart ?? fallback)
        let end = activity?.endAt ?? cal.date(byAdding: .minute, value: 30, to: start)!

        _title = State(initialValue: activity?.title ?? "")
        _startAt = State(initialValue: start)
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
                            if endAt < newStart {
                                endAt = cal.date(byAdding: .minute, value: 30, to: newStart) ?? newStart
                            }
                        }

                    Toggle("Set end time", isOn: $hasEnd)

                    if hasEnd {
                        DatePicker("End", selection: $endAt, in: startAt..., displayedComponents: [.date, .hourAndMinute])
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

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEnd: Date? = hasEnd ? endAt : nil

        if let activity {
            activity.title = t
            activity.startAt = startAt
            activity.endAt = finalEnd
        } else {
            let new = Activity(title: t, startAt: startAt, endAt: finalEnd)
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
