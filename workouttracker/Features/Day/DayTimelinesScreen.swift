import SwiftUI
import SwiftData

struct DayTimelineScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var activities: [Activity]

    private let day: Date
    private let onEdit: (Activity) -> Void
    private let onCreateAt: (Date) -> Void

    // Timeline sizing knobs (opinionated defaults)
    private let hourHeight: CGFloat = 80
    private let gutterWidth: CGFloat = 58
    private let sidePadding: CGFloat = 12
    private let laneGap: CGFloat = 6

    init(day: Date,
         onEdit: @escaping (Activity) -> Void,
         onCreateAt: @escaping (Date) -> Void) {
        self.day = day
        self.onEdit = onEdit
        self.onCreateAt = onCreateAt

        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        _activities = Query(
            filter: #Predicate<Activity> { a in
                // Overlap rule (no forced unwrap):
                // start < dayEnd AND (endOrStart) >= dayStart
                a.startAt < end && ((a.endAt ?? a.startAt) >= start)
            },
            sort: [SortDescriptor(\Activity.startAt, order: .forward)]
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                timeline(proxy: proxy)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 24)
            }
            .onAppear {
                // Snap view near current hour when opening "Today"
                guard Calendar.current.isDateInToday(day) else { return }
                let hour = Calendar.current.component(.hour, from: Date())
                DispatchQueue.main.async {
                    proxy.scrollTo(hour, anchor: .top)
                }
            }
        }
    }

    private func timeline(proxy: ScrollViewProxy) -> some View {
        let startOfDay = Calendar.current.startOfDay(for: day)
        let totalHeight = hourHeight * 24

        // Convert Activities -> layout segments (minutes, lanes)
        let laidOut = TimelineLayout.layout(
            activities: activities,
            dayStart: startOfDay,
            defaultDurationMinutes: 30
        )

        return GeometryReader { geo in
            let availableWidth = max(0, geo.size.width - gutterWidth - sidePadding * 2)
            let laneCount = max(1, laidOut.laneCount)
            let laneWidth = (availableWidth - laneGap * CGFloat(laneCount - 1)) / CGFloat(laneCount)

            ZStack(alignment: .topLeading) {

                TimelineGrid(hourHeight: hourHeight, gutterWidth: gutterWidth)
                    .frame(height: totalHeight)

                // Tap anywhere (empty space) to create a new activity at that time.
                // This is below blocks, so blocks still receive taps for editing.
                TimelineTapLayer(totalHeight: totalHeight) { y in
                    let minutes = minutesFromY(y)
                    let date = dateFromMinutes(minutes, dayStart: startOfDay)
                    onCreateAt(date)
                }
                .frame(height: totalHeight)

                // "Now" indicator for Today
                if Calendar.current.isDateInToday(day) {
                    let nowMinutes = clampMinutes(Int(Date().timeIntervalSince(startOfDay) / 60))
                    let y = yFromMinutes(nowMinutes)
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(.red)
                        .offset(x: gutterWidth, y: y)
                        .opacity(0.75)
                }

                // Activity blocks
                ForEach(laidOut.items, id: \.activity.persistentModelID) { item in
                    let x = gutterWidth + sidePadding + CGFloat(item.lane) * (laneWidth + laneGap)
                    let y = yFromMinutes(item.startMinute)
                    let h = max(28, heightFromMinutes(item.durationMinutes))

                    ActivityBlockView(
                        activity: item.activity,
                        dayStart: startOfDay,
                        startMinute: item.startMinute,
                        endMinute: item.endMinute,
                        clippedStart: item.clippedStart,
                        clippedEnd: item.clippedEnd,
                        hourHeight: hourHeight,
                        onEdit: { onEdit(item.activity) }
                    )
                    .frame(width: max(60, laneWidth), height: h, alignment: .topLeading)
                    .offset(x: x, y: y)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(item.activity)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .frame(height: totalHeight)
        }
        .frame(height: totalHeight) // important: gives GeometryReader a height
    }

    // MARK: - Minute <-> Pixel mapping

    private func yFromMinutes(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60.0) * hourHeight
    }

    private func heightFromMinutes(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60.0) * hourHeight
    }

    private func minutesFromY(_ y: CGFloat) -> Int {
        let raw = Int((y / hourHeight) * 60.0)
        // Snap to 5-minute increments (makes it feel nicer)
        let snapped = Int((Double(raw) / 5.0).rounded()) * 5
        return clampMinutes(snapped)
    }

    private func clampMinutes(_ m: Int) -> Int {
        min(max(m, 0), 24 * 60 - 1)
    }

    private func dateFromMinutes(_ minutes: Int, dayStart: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: dayStart) ?? dayStart
    }
}

// MARK: - Grid (24 rows, one per hour)

private struct TimelineGrid: View {
    let hourHeight: CGFloat
    let gutterWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 10) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: gutterWidth, alignment: .trailing)
                        .padding(.top, 2)

                    VStack(spacing: 0) {
                        Divider()
                        Spacer()
                    }
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour) // so ScrollViewReader can scroll to this hour
            }
        }
    }
}

// MARK: - Tap layer (get Y position -> minutes)

private struct TimelineTapLayer: View {
    let totalHeight: CGFloat
    let onTapY: (CGFloat) -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let y = value.location.y
                        guard y >= 0 && y <= totalHeight else { return }
                        onTapY(y)
                    }
            )
    }
}

// MARK: - Activity block appearance

private struct ActivityBlockView: View {
    let activity: Activity
    let dayStart: Date

    let startMinute: Int
    let endMinute: Int
    let clippedStart: Bool
    let clippedEnd: Bool
    let hourHeight: CGFloat

    let onEdit: () -> Void
    
    var body: some View {
        let timeLabel = "\(formatHM(startMinute)) – \(formatHM(endMinute))"

        VStack(alignment: .leading, spacing: 6) {
            Text(activity.title.isEmpty ? "Untitled" : activity.title)
                .font(.headline)
                .lineLimit(2)

            Text(timeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if clippedStart || clippedEnd {
                Text(clipNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.tint.opacity(0.18))
        )
        .overlay(alignment: .topLeading) {
            if clippedStart { ClipMarker(systemName: "chevron.up") }
        }
        .overlay(alignment: .bottomLeading) {
            if clippedEnd { ClipMarker(systemName: "chevron.down") }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.tint.opacity(0.35), lineWidth: 1)
        )
    }

    private var clipNote: String {
        switch (clippedStart, clippedEnd) {
        case (true, true): return "Spans beyond this day"
        case (true, false): return "Started before this day"
        case (false, true): return "Ends after this day"
        case (false, false): return ""
        }
    }

    private func formatHM(_ minutes: Int) -> String {
        let m = min(max(minutes, 0), 24 * 60)
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }
}

private struct ClipMarker: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .padding(6)
    }
}

// MARK: - Layout (overlaps -> lanes)

private enum TimelineLayout {
    struct Result {
        let items: [Item]
        let laneCount: Int
    }

    struct Item {
        let activity: Activity
        let startMinute: Int
        let endMinute: Int
        let durationMinutes: Int
        let lane: Int

        let clippedStart: Bool
        let clippedEnd: Bool
    }

    static func layout(
        activities: [Activity],
        dayStart: Date,
        defaultDurationMinutes: Int
    ) -> Result {

        var segments: [(activity: Activity, start: Int, end: Int, clippedStart: Bool, clippedEnd: Bool)] = []
        segments.reserveCapacity(activities.count)

        for a in activities {
            let rawStart = Int(a.startAt.timeIntervalSince(dayStart) / 60)

            let endDate = a.endAt
                ?? Calendar.current.date(byAdding: .minute, value: defaultDurationMinutes, to: a.startAt)!

            let rawEnd = Int(endDate.timeIntervalSince(dayStart) / 60)

            let clippedStart = rawStart < 0
            let clippedEnd = rawEnd > 24 * 60

            let clampedStart = clamp(rawStart)
            var clampedEnd = clamp(rawEnd)

            if clampedEnd <= clampedStart {
                clampedEnd = min(clampedStart + 15, 24 * 60)
            }

            segments.append((a, clampedStart, clampedEnd, clippedStart, clippedEnd))
        }

        segments.sort {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.end < $1.end
        }

        // Greedy lane assignment
        var laneEnds: [Int] = []
        var out: [Item] = []
        out.reserveCapacity(segments.count)

        for s in segments {
            var lane = 0
            var placed = false

            for i in 0..<laneEnds.count {
                if s.start >= laneEnds[i] {
                    lane = i
                    laneEnds[i] = s.end
                    placed = true
                    break
                }
            }

            if !placed {
                lane = laneEnds.count
                laneEnds.append(s.end)
            }

            out.append(
                Item(
                    activity: s.activity,
                    startMinute: s.start,
                    endMinute: s.end,
                    durationMinutes: s.end - s.start,
                    lane: lane,
                    clippedStart: s.clippedStart,
                    clippedEnd: s.clippedEnd
                )
            )
        }

        return Result(items: out, laneCount: max(1, laneEnds.count))
    }

    private static func clamp(_ m: Int) -> Int {
        min(max(m, 0), 24 * 60)
    }
}

