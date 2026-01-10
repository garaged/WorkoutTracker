import SwiftUI
import SwiftData

struct DayScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var activities: [Activity]

    private let day: Date
    private let onEdit: (Activity) -> Void

    init(day: Date, onEdit: @escaping (Activity) -> Void) {
        self.day = day
        self.onEdit = onEdit

        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        _activities = Query(
            filter: #Predicate<Activity> { a in
                a.startAt >= start && a.startAt < end
            },
            sort: [SortDescriptor(\Activity.startAt, order: .forward)]
        )
    }

    var body: some View {
        Group {
            if activities.isEmpty {
                ContentUnavailableView(
                    "No activities",
                    systemImage: "calendar",
                    description: Text("Add something for this day.")
                )
            } else {
                List {
                    ForEach(activities) { a in
                        Button {
                            onEdit(a)
                        } label: {
                            ActivityRow(activity: a)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
    }

    private func delete(_ indexSet: IndexSet) {
        for i in indexSet {
            modelContext.delete(activities[i])
        }
        // SwiftData usually persists automatically; explicit save is optional:
        // try? modelContext.save()
    }
}

private struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(activity.title)
                .font(.headline)

            HStack(spacing: 8) {
                Text(activity.startAt, format: .dateTime.hour().minute())
                Text("–").foregroundStyle(.secondary)

                if let end = activity.endAt {
                    Text(end, format: .dateTime.hour().minute())
                } else {
                    Text("open-ended")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
