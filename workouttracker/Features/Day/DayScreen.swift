//import SwiftUI
//import SwiftData
//
//struct DayScreen: View {
//    @Environment(\.modelContext) private var modelContext
//    @Query private var activities: [Activity]
//
//    private let day: Date
//    private let onEdit: (Activity) -> Void
//
//    private var dayKey: String { day.dayKey() }
//
//    init(day: Date, onEdit: @escaping (Activity) -> Void) {
//        self.day = day
//        self.onEdit = onEdit
//
//        let start = Calendar.current.startOfDay(for: day)
//        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
//
//        _activities = Query(
//            filter: #Predicate<Activity> { a in
//                a.startAt >= start && a.startAt < end
//            },
//            sort: [SortDescriptor(\Activity.startAt, order: .forward)]
//        )
//    }
//
//    var body: some View {
//        Group {
//            if activities.isEmpty {
//                ContentUnavailableView(
//                    "No activities",
//                    systemImage: "calendar",
//                    description: Text("Add something for this day.")
//                )
//            } else {
//                List {
//                    ForEach(activities) { a in
//                        Button {
//                            onEdit(a)
//                        } label: {
//                            ActivityRow(activity: a)
//                        }
//                        .buttonStyle(.plain)
//                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
//                            Button {
//                                toggleDone(a)
//                            } label: {
//                                Label(a.isDone ? "Undone" : "Done",
//                                      systemImage: a.isDone ? "arrow.uturn.left" : "checkmark")
//                            }
//                        }
//                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
//                            if a.templateId != nil {
//                                Button(role: .destructive) {
//                                    skipToday(a)
//                                } label: {
//                                    Label("Skip today", systemImage: "forward.end")
//                                }
//                            }
//                        }
//                    }
//                    .onDelete(perform: delete)
//                }
//            }
//        }
//        .task(id: dayKey) {
//            do {
//                try TemplatePreloader.ensureDayIsPreloaded(for: day, context: modelContext)
//            } catch {
//                print("Preload failed: \(error)")
//            }
//        }
//    }
//
//    // MARK: - Actions
//
//    private func delete(_ indexSet: IndexSet) {
//        for i in indexSet {
//            deleteActivityWithOverrideIfNeeded(activities[i])
//        }
//        try? modelContext.save()
//    }
//
//    private func deleteActivityWithOverrideIfNeeded(_ a: Activity) {
//        if let templateId = a.templateId {
//            modelContext.insert(
//                TemplateInstanceOverride(templateId: templateId, dayKey: dayKey, action: .deletedToday)
//            )
//        }
//        modelContext.delete(a)
//    }
//
//    private func toggleDone(_ a: Activity) {
//        if a.status == .done {
//            a.status = .planned
//            a.completedAt = nil
//        } else {
//            a.status = .done
//            a.completedAt = Date()
//        }
//        try? modelContext.save()
//    }
//
//    private func skipToday(_ a: Activity) {
//        guard let templateId = a.templateId else { return }
//
//        modelContext.insert(
//            TemplateInstanceOverride(templateId: templateId, dayKey: dayKey, action: .skippedToday)
//        )
//        a.status = .skipped
//        try? modelContext.save()
//    }
//}
//
//// Keep this in the same file for now to avoid scope surprises.
//private struct ActivityRow: View {
//    let activity: Activity
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 6) {
//            HStack(spacing: 8) {
//                Text(activity.title)
//                    .font(.headline)
//                    .strikethrough(activity.isDone)
//
//                if activity.isDone {
//                    Image(systemName: "checkmark.circle.fill")
//                        .foregroundStyle(.secondary)
//                } else if activity.status == .skipped {
//                    Text("skipped")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
//            }
//
//            HStack(spacing: 8) {
//                Text(activity.startAt, format: .dateTime.hour().minute())
//                Text("–").foregroundStyle(.secondary)
//
//                if let end = activity.endAt {
//                    Text(end, format: .dateTime.hour().minute())
//                } else {
//                    Text("open-ended").foregroundStyle(.secondary)
//                }
//            }
//            .font(.subheadline)
//            .foregroundStyle(.secondary)
//        }
//        .padding(.vertical, 4)
//    }
//}
