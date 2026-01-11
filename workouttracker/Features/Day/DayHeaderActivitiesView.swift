import SwiftUI

struct DayHeaderActivitiesView: View {
    let dayStart: Date
    let activities: [Activity]
    let defaultDurationMinutes: Int

    let onSelect: (Activity) -> Void

    var body: some View {
        let buckets = DayActivityBucketer.bucket(
            activities: activities,
            dayStart: dayStart,
            defaultDurationMinutes: defaultDurationMinutes
        )

        if buckets.allDay.isEmpty && buckets.multiDay.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 10) {
                if !buckets.multiDay.isEmpty {
                    headerRow(title: "Multi-day") {
                        VStack(spacing: 6) {
                            ForEach(buckets.multiDay, id: \.persistentModelID) { a in
                                MultiDayBar(activity: a, dayStart: dayStart, defaultDurationMinutes: defaultDurationMinutes) {
                                    onSelect(a)
                                }
                            }
                        }
                    }
                }

                if !buckets.allDay.isEmpty {
                    headerRow(title: "All-day") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                            ForEach(buckets.allDay, id: \.persistentModelID) { a in
                                AllDayChip(activity: a) {
                                    onSelect(a)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func headerRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            content()
        }
    }
}

private struct AllDayChip: View {
    let activity: Activity
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(activityTitle(activity))
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct MultiDayBar: View {
    let activity: Activity
    let dayStart: Date
    let defaultDurationMinutes: Int
    let onTap: () -> Void

    var body: some View {
        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let end = DayActivityBucketer.resolvedEnd(for: activity, defaultDurationMinutes: defaultDurationMinutes, calendar: cal)

        let continuesFromLeft = activity.startAt < dayStart
        let continuesToRight  = end > dayEnd

        return Button(action: onTap) {
            HStack(spacing: 8) {
                if continuesFromLeft {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(activityTitle(activity))
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if continuesToRight {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private func activityTitle(_ a: Activity) -> String {
    let t = a.title.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? "Activity" : t
}
