import SwiftUI
import SwiftData

struct DayTimelineScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [Activity]

    private let day: Date
    private let onEdit: (Activity) -> Void
    private let onCreateAt: (Date) -> Void
    private let onCreateRange: (Date, Date) -> Void

    // Layout knobs
    private let hourHeight: CGFloat = 80
    private let gutterWidth: CGFloat = 58
    private let sidePadding: CGFloat = 12
    private let laneGap: CGFloat = 6

    private let defaultDurationMinutes: Int = 30

    init(
        day: Date,
        onEdit: @escaping (Activity) -> Void,
        onCreateAt: @escaping (Date) -> Void,
        onCreateRange: @escaping (Date, Date) -> Void
    ) {
        self.day = day
        self.onEdit = onEdit
        self.onCreateAt = onCreateAt
        self.onCreateRange = onCreateRange

        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        // ✅ Overlap predicate (no forced unwrap)
        _activities = Query(
            filter: #Predicate<Activity> { a in
                a.startAt < end && ((a.endAt ?? a.startAt) > start)
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
                guard Calendar.current.isDateInToday(day) else { return }
                let hour = Calendar.current.component(.hour, from: Date())
                DispatchQueue.main.async {
                    proxy.scrollTo(hour, anchor: .top)
                }
            }
        }
    }

    private func timeline(proxy: ScrollViewProxy) -> some View {
        let dayStart = Calendar.current.startOfDay(for: day)
        let totalHeight = hourHeight * 24

        let laidOut = TimelineLayout.layout(
            activities: activities,
            dayStart: dayStart,
            defaultDurationMinutes: defaultDurationMinutes
        )

        return GeometryReader { geo in
            let availableWidth = max(0, geo.size.width - gutterWidth - sidePadding * 2)
            let laneCount = max(1, laidOut.laneCount)
            let laneWidth = (availableWidth - laneGap * CGFloat(laneCount - 1)) / CGFloat(laneCount)

            ZStack(alignment: .topLeading) {

                TimelineGrid(hourHeight: hourHeight, gutterWidth: gutterWidth)
                    .frame(height: totalHeight)

                // ✅ Tap to create + press(0.2s)+drag to create a range
                TimelineInteractionLayer(
                    totalHeight: totalHeight,
                    hourHeight: hourHeight,
                    snapMinutes: 5,
                    minDurationMinutes: 15,
                    onTapMinute: { minutes in
                        let start = dateFromMinutes(minutes, dayStart: dayStart)
                        onCreateAt(start)
                    },
                    onDragMinutesRange: { startMin, endMin in
                        let start = dateFromMinutes(startMin, dayStart: dayStart)
                        let end = dateFromMinutes(endMin, dayStart: dayStart)
                        onCreateRange(start, end)
                    }
                )
                .frame(height: totalHeight)

                // Now indicator
                if Calendar.current.isDateInToday(day) {
                    let nowMinutes = clampMinutes(Int(Date().timeIntervalSince(dayStart) / 60))
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(.red)
                        .offset(x: gutterWidth, y: yFromMinutes(nowMinutes))
                        .opacity(0.75)
                }

                // Activity blocks
                ForEach(laidOut.items, id: \.activity.persistentModelID) { item in
                    let x = gutterWidth + sidePadding + CGFloat(item.lane) * (laneWidth + laneGap)
                    let y = yFromMinutes(item.displayStartMinute)
                    let h = max(28, heightFromMinutes(item.displayDurationMinutes))

                    InteractiveActivityBlockView(
                        activity: item.activity,
                        dayStart: dayStart,
                        displayStartMinute: item.displayStartMinute,
                        displayEndMinute: item.displayEndMinute,
                        clippedStart: item.clippedStart,
                        clippedEnd: item.clippedEnd,
                        hourHeight: hourHeight,
                        defaultDurationMinutes: defaultDurationMinutes,
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
        .frame(height: totalHeight)
    }

    // MARK: - Mapping

    private func yFromMinutes(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60.0) * hourHeight
    }

    private func heightFromMinutes(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60.0) * hourHeight
    }

    private func clampMinutes(_ m: Int) -> Int {
        min(max(m, 0), 24 * 60 - 1)
    }

    private func dateFromMinutes(_ minutes: Int, dayStart: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: dayStart) ?? dayStart
    }
}

// MARK: - Grid

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
                .id(hour)
            }
        }
    }
}

// MARK: - Interaction Layer (tap + press-drag range selection)

private struct TimelineInteractionLayer: View {
    let totalHeight: CGFloat
    let hourHeight: CGFloat
    let snapMinutes: Int
    let minDurationMinutes: Int

    let onTapMinute: (Int) -> Void
    let onDragMinutesRange: (Int, Int) -> Void

    @State private var selecting = false
    @State private var startY: CGFloat = 0
    @State private var currentY: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())

            if selecting {
                selectionRect
            }
        }
        // tap-to-create
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                let y = clampY(value.location.y)
                let m = minutes(forY: y)
                onTapMinute(m)
            }
        )
        // press+drag to create range (prevents fighting ScrollView scroll)
        .gesture(
            LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    switch value {
                    case .first(true):
                        // waiting for drag
                        break
                    case .second(true, let drag?):
                        if !selecting {
                            selecting = true
                            startY = clampY(drag.startLocation.y)
                            currentY = clampY(drag.startLocation.y)
                        }
                        currentY = clampY(drag.location.y)
                    default:
                        break
                    }
                }
                .onEnded { value in
                    defer { selecting = false }

                    guard case .second(true, let drag?) = value else { return }

                    let y1 = clampY(drag.startLocation.y)
                    let y2 = clampY(drag.location.y)

                    let a = minutes(forY: min(y1, y2))
                    let b = minutes(forY: max(y1, y2))

                    let startMin = a
                    let endMin = max(b, startMin + minDurationMinutes)

                    // Allow end at 1440 (midnight next day)
                    onDragMinutesRange(startMin, min(endMin, 24 * 60))
                }
        )
    }

    private var selectionRect: some View {
        let top = min(startY, currentY)
        let bottom = max(startY, currentY)
        let h = max(6, bottom - top)

        return RoundedRectangle(cornerRadius: 12)
            .fill(.tint.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.tint.opacity(0.35), lineWidth: 1)
            )
            .frame(height: h)
            .offset(x: 58, y: top) // push right past the hour gutter (matches DayTimeline layout)
            .padding(.trailing, 12)
            .allowsHitTesting(false)
    }

    private func clampY(_ y: CGFloat) -> CGFloat {
        min(max(y, 0), totalHeight)
    }

    private func minutes(forY y: CGFloat) -> Int {
        let raw = Int((y / hourHeight) * 60.0)
        let snapped = Int((Double(raw) / Double(snapMinutes)).rounded()) * snapMinutes
        return min(max(snapped, 0), 24 * 60)
    }
}

// MARK: - Interactive Activity Block (move + resize + clip markers)

private struct InteractiveActivityBlockView: View {
    let activity: Activity
    let dayStart: Date

    let displayStartMinute: Int
    let displayEndMinute: Int
    let clippedStart: Bool
    let clippedEnd: Bool

    let hourHeight: CGFloat
    let defaultDurationMinutes: Int
    let onEdit: () -> Void

    @State private var isDragging = false
    @State private var dragDeltaMinutes: Int = 0

    @State private var isResizing = false
    @State private var resizeDeltaMinutes: Int = 0

    private let snapMinutes: Int = 5
    private let minDurationMinutes: Int = 15
    private let maxSpanDays: Int = 7

    var body: some View {
        let baseStart = rawStartMinute()
        let baseEnd = rawEndMinute()

        let previewStart = baseStart + dragDeltaMinutes
        let previewEnd = baseEnd + dragDeltaMinutes + resizeDeltaMinutes

        let previewClippedStart = previewStart < 0
        let previewClippedEnd = previewEnd > 24 * 60

        let timeLabel = "\(formatTime(previewStart)) – \(formatTime(previewEnd))"

        VStack(alignment: .leading, spacing: 6) {
            Text(activity.title.isEmpty ? "Untitled" : activity.title)
                .font(.headline)
                .lineLimit(2)

            Text(timeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(.tint.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.tint.opacity(0.35), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if isDragging || isResizing {
                Text(isDragging ? "Move" : "Resize")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }
        }
        .overlay(alignment: .topLeading) {
            if clippedStart || previewClippedStart { ClipMarker(systemName: "chevron.up") }
        }
        .overlay(alignment: .bottomLeading) {
            if clippedEnd || previewClippedEnd { ClipMarker(systemName: "chevron.down") }
        }
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
                .padding(8)
                .highPriorityGesture(resizeGesture)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .gesture(moveGesture)
        .onTapGesture {
            if !isDragging && !isResizing { onEdit() }
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard canMoveInThisDay() else { return }
                isDragging = true
                dragDeltaMinutes = snap(minutesFromTranslation(value.translation.height))
            }
            .onEnded { value in
                guard canMoveInThisDay() else {
                    isDragging = false
                    dragDeltaMinutes = 0
                    return
                }

                let delta = snap(minutesFromTranslation(value.translation.height))
                commitMove(deltaMinutes: delta)

                isDragging = false
                dragDeltaMinutes = 0
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                isResizing = true
                resizeDeltaMinutes = snap(minutesFromTranslation(value.translation.height))
            }
            .onEnded { value in
                let delta = snap(minutesFromTranslation(value.translation.height))
                commitResize(deltaMinutes: delta)

                isResizing = false
                resizeDeltaMinutes = 0
            }
    }

    private func commitMove(deltaMinutes: Int) {
        let duration = normalizedDurationMinutes()
        let newStart = clamp(rawStartMinute() + deltaMinutes, 0, 24 * 60 - 1)

        activity.startAt = dateFromMinutes(newStart)
        activity.endAt = dateFromMinutes(newStart + duration)
    }

    private func commitResize(deltaMinutes: Int) {
        let baseStart = rawStartMinute()
        let baseEnd = rawEndMinute()

        let minEnd = baseStart + minDurationMinutes
        let maxEnd = baseStart + maxSpanDays * 24 * 60

        let desiredEnd = baseEnd + deltaMinutes
        let newEnd = clamp(desiredEnd, minEnd, maxEnd)

        activity.endAt = dateFromMinutes(newEnd)
        if let end = activity.endAt, end <= activity.startAt {
            activity.endAt = dateFromMinutes(baseStart + minDurationMinutes)
        }
    }

    private func canMoveInThisDay() -> Bool {
        let s = rawStartMinute()
        return (0 <= s && s < 24 * 60)
    }

    private func rawStartMinute() -> Int {
        Int(activity.startAt.timeIntervalSince(dayStart) / 60)
    }

    private func rawEndMinute() -> Int {
        let endDate = activity.endAt
            ?? Calendar.current.date(byAdding: .minute, value: defaultDurationMinutes, to: activity.startAt)!
        return Int(endDate.timeIntervalSince(dayStart) / 60)
    }

    private func normalizedDurationMinutes() -> Int {
        max(minDurationMinutes, rawEndMinute() - rawStartMinute())
    }

    private var resizeHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Resize")
    }

    private func minutesFromTranslation(_ dy: CGFloat) -> Int {
        Int((dy / hourHeight) * 60.0)
    }

    private func snap(_ minutes: Int) -> Int {
        Int((Double(minutes) / Double(snapMinutes)).rounded()) * snapMinutes
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int {
        min(max(v, lo), hi)
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: dayStart) ?? dayStart
    }

    private func formatTime(_ minutes: Int) -> String {
        let day = 24 * 60
        let dayOffset = Int(floor(Double(minutes) / Double(day)))
        var mod = minutes % day
        if mod < 0 { mod += day }

        let h = mod / 60
        let m = mod % 60
        let base = String(format: "%02d:%02d", h, m)

        if dayOffset == 0 { return base }
        return base + (dayOffset > 0 ? " (+\(dayOffset)d)" : " (\(dayOffset)d)")
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

// MARK: - Layout (clamp to day window + lane packing)

private enum TimelineLayout {
    struct Result {
        let items: [Item]
        let laneCount: Int
    }

    struct Item {
        let activity: Activity

        let displayStartMinute: Int
        let displayEndMinute: Int
        let displayDurationMinutes: Int

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
                    displayStartMinute: s.start,
                    displayEndMinute: s.end,
                    displayDurationMinutes: s.end - s.start,
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
