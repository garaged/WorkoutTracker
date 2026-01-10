import SwiftUI
import SwiftData

struct DayTimelineScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [Activity]
    @State private var isSelectingRange: Bool = false
    @State private var hoveredLaneWhileDraggingBlock: Int? = nil

    private let day: Date
    private let onEdit: (Activity) -> Void
    private let onCreateAt: (Date, Int) -> Void
    private let onCreateRange: (Date, Date, Int) -> Void

    // Layout knobs
    private let hourHeight: CGFloat = 80
    private let gutterWidth: CGFloat = 58
    private let sidePadding: CGFloat = 12
    private let laneGap: CGFloat = 6

    private let defaultDurationMinutes: Int = 30

    init(
        day: Date,
        onEdit: @escaping (Activity) -> Void,
        onCreateAt: @escaping (Date, Int) -> Void,
        onCreateRange: @escaping (Date, Date, Int) -> Void
    ) {
        self.day = day
        self.onEdit = onEdit
        self.onCreateAt = onCreateAt
        self.onCreateRange = onCreateRange

        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        // Overlap predicate (no forced unwrap)
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
            .scrollDisabled(isSelectingRange)
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

        let laneByID: [PersistentIdentifier: Int] = Dictionary(
            uniqueKeysWithValues: laidOut.items.map { ($0.activity.persistentModelID, $0.lane) }
        )

        return GeometryReader { geo in
            let availableWidth = max(0, geo.size.width - gutterWidth - sidePadding * 2)
            let laneCount = max(3, laidOut.laneCount)
            let laneWidth = (availableWidth - laneGap * CGFloat(laneCount - 1)) / CGFloat(laneCount)

            let lanesX0 = gutterWidth + sidePadding
            let laneSpan = laneWidth + laneGap

            ZStack(alignment: .topLeading) {

                TimelineGrid(hourHeight: hourHeight, gutterWidth: gutterWidth)
                    .frame(height: totalHeight)

                // Tap + press-drag selection (lane chosen by x coordinate)
                TimelineInteractionLayer(
                    totalHeight: totalHeight,
                    hourHeight: hourHeight,
                    snapMinutes: 5,
                    minDurationMinutes: 15,
                    laneCount: laneCount,
                    laneWidth: laneWidth,
                    laneGap: laneGap,
                    lanesX0: lanesX0,
                    isSelecting: $isSelectingRange,
                    onTap: { minute, lane in
                        let start = dateFromMinutes(minute, dayStart: dayStart)
                        onCreateAt(start, lane)
                    },
                    onDragRange: { startMin, endMin, lane in
                        let start = dateFromMinutes(startMin, dayStart: dayStart)
                        let end = dateFromMinutes(endMin, dayStart: dayStart)
                        onCreateRange(start, end, lane)
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

                if let hl = hoveredLaneWhileDraggingBlock {
                    LaneHighlight(
                        x: lanesX0 + CGFloat(hl) * (laneWidth + laneGap),
                        width: max(44, laneWidth),
                        height: totalHeight
                    )
                }

                // Activity blocks
                ForEach(laidOut.items, id: \.activity.persistentModelID) { item in
                    let x = lanesX0 + CGFloat(item.lane) * laneSpan
                    let y = yFromMinutes(item.displayStartMinute)
                    let h = max(28, heightFromMinutes(item.displayDurationMinutes))

                    InteractiveActivityBlockView(
                        activity: item.activity,
                        dayStart: dayStart,
                        clippedStart: item.clippedStart,
                        clippedEnd: item.clippedEnd,
                        hourHeight: hourHeight,
                        defaultDurationMinutes: defaultDurationMinutes,
                        currentLane: item.lane,
                        laneCount: laneCount,
                        laneWidth: laneWidth,
                        laneGap: laneGap,
                        onEdit: { onEdit(item.activity) },
                        onCommitLaneChange: { oldLane, newLane in
                            commitLaneChange(
                                moved: item.activity,
                                oldLane: oldLane,
                                newLane: newLane,
                                all: activities,
                                laneByID: laneByID,
                                maxLanes: laneCount,
                                defaultDurationMinutes: defaultDurationMinutes
                            )
                        },
                        onHoverLane: { lane in
                            hoveredLaneWhileDraggingBlock = lane
                        },
                        onEndHoverLane: {
                            hoveredLaneWhileDraggingBlock = nil
                        }
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
    
    private func resolveLaneHintsAfterDrop(
        moved: Activity,
        pinnedLane: Int,
        all: [Activity],
        maxLanes: Int,
        defaultDurationMinutes: Int
    ) {
        let lanes = max(1, maxLanes)
        func clampLane(_ x: Int) -> Int { min(max(x, 0), lanes - 1) }

        let group = all.filter { overlaps($0, moved, defaultDurationMinutes: defaultDurationMinutes) }
        guard group.count > 1 else { return }

        var laneEnds = Array(repeating: Date.distantPast, count: lanes)

        func assign(_ a: Activity, _ lane: Int) {
            let l = clampLane(lane)
            a.laneHint = l
            laneEnds[l] = effectiveEnd(a, defaultDurationMinutes: defaultDurationMinutes)
        }

        // pin moved first
        assign(moved, pinnedLane)

        let others = group
            .filter { $0.persistentModelID != moved.persistentModelID }
            .sorted { $0.startAt < $1.startAt }

        for a in others {
            let s = a.startAt
            let preferred = clampLane(a.laneHint)
            let candidates = [preferred] + (0..<lanes).filter { $0 != preferred }

            var chosen: Int? = nil
            for l in candidates {
                if laneEnds[l] <= s {
                    chosen = l
                    break
                }
            }
            if chosen == nil {
                chosen = laneEnds.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            }
            assign(a, chosen!)
        }
    }
    
    private func effectiveEnd(_ a: Activity, defaultDurationMinutes: Int) -> Date {
        a.endAt ?? Calendar.current.date(byAdding: .minute, value: defaultDurationMinutes, to: a.startAt)!
    }

    private func overlaps(_ a: Activity, _ b: Activity, defaultDurationMinutes: Int) -> Bool {
        a.startAt < effectiveEnd(b, defaultDurationMinutes: defaultDurationMinutes)
        && b.startAt < effectiveEnd(a, defaultDurationMinutes: defaultDurationMinutes)
    }

    private func commitLaneChange(
        moved: Activity,
        oldLane: Int,
        newLane: Int,
        all: [Activity],
        laneByID: [PersistentIdentifier: Int],
        maxLanes: Int,
        defaultDurationMinutes: Int
    ) {
        let lanes = max(1, maxLanes)
        func clampLane(_ x: Int) -> Int { min(max(x, 0), lanes - 1) }

        let oldL = clampLane(oldLane)
        let newL = clampLane(newLane)

        guard oldL != newL else {
            moved.laneHint = newL
            return
        }

        // Build the overlap group for moved
        let group = all.filter { overlaps($0, moved, defaultDurationMinutes: defaultDurationMinutes) }

        // Determine who is CURRENTLY DISPLAYED in the target lane and overlaps moved
        let conflictsInTargetLane = group.filter { a in
            a.persistentModelID != moved.persistentModelID
            && (laneByID[a.persistentModelID] ?? a.laneHint) == newL
        }

        // ✅ Swap only when there is exactly ONE conflict (A ↔ B), and it is safe
        if conflictsInTargetLane.count == 1 {
            let other = conflictsInTargetLane[0]

            // Is old lane currently free of overlapping blocks for `other`?
            let oldLaneBlockedForOther = group.contains { a in
                a.persistentModelID != moved.persistentModelID
                && a.persistentModelID != other.persistentModelID
                && overlaps(a, other, defaultDurationMinutes: defaultDurationMinutes)
                && (laneByID[a.persistentModelID] ?? a.laneHint) == oldL
            }

            if !oldLaneBlockedForOther {
                // Do the swap
                moved.laneHint = newL
                other.laneHint = oldL
                return
            }
        }

        // Fallback: just pin moved in the new lane and re-pack the overlap group
        moved.laneHint = newL
        resolveLaneHintsAfterDrop(
            moved: moved,
            pinnedLane: newL,
            all: all,
            maxLanes: lanes,
            defaultDurationMinutes: defaultDurationMinutes
        )
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

// MARK: - Interaction Layer (tap + press-drag range + horizontal lane select)

private struct TimelineInteractionLayer: View {
    let totalHeight: CGFloat
    let hourHeight: CGFloat
    let snapMinutes: Int
    let minDurationMinutes: Int

    let laneCount: Int
    let laneWidth: CGFloat
    let laneGap: CGFloat
    let lanesX0: CGFloat

    @Binding var isSelecting: Bool

    let onTap: (Int, Int) -> Void
    let onDragRange: (Int, Int, Int) -> Void

    @State private var selecting = false
    @State private var startY: CGFloat = 0
    @State private var currentY: CGFloat = 0
    @State private var selectedLane: Int = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())

            if selecting {
                // ✅ highlight the hovered lane (full height)
                LaneHighlight(
                    x: lanesX0 + CGFloat(selectedLane) * (laneWidth + laneGap),
                    width: max(44, laneWidth),
                    height: totalHeight
                )

                selectionRect
            }
        }
        .overlay {
            GestureCaptureView(
                onTap: { pt in
                    let y = clampY(pt.y)
                    let m = minutes(forY: y)
                    let lane = laneForX(pt.x)
                    onTap(m, lane)
                },
                onLongPressBegan: { pt in
                    selecting = true
                    isSelecting = true

                    startY = clampY(pt.y)
                    currentY = clampY(pt.y)
                    selectedLane = laneForX(pt.x)
                },
                onLongPressChanged: { pt in
                    guard selecting else { return }
                    currentY = clampY(pt.y)
                    selectedLane = laneForX(pt.x)
                },
                onLongPressEnded: { startPt, endPt in
                    defer {
                        selecting = false
                        isSelecting = false
                    }

                    let y1 = clampY(startPt.y)
                    let y2 = clampY(endPt.y)

                    let a = minutes(forY: min(y1, y2))
                    let b = minutes(forY: max(y1, y2))

                    let startMin = a
                    let endMin = max(b, startMin + minDurationMinutes)

                    let lane = laneForX(endPt.x)
                    onDragRange(startMin, min(endMin, 24 * 60), lane)
                }
            )
        }
    }

    private var selectionRect: some View {
        let top = min(startY, currentY)
        let bottom = max(startY, currentY)
        let h = max(6, bottom - top)

        let x = lanesX0 + CGFloat(selectedLane) * (laneWidth + laneGap)

        return RoundedRectangle(cornerRadius: 12)
            .fill(.tint.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.tint.opacity(0.35), lineWidth: 1)
            )
            .frame(width: max(44, laneWidth), height: h)
            .offset(x: x, y: top)
            .overlay(alignment: .topTrailing) {
                Text("Lane \(selectedLane + 1)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(6)
            }
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

    private func laneForX(_ x: CGFloat) -> Int {
        let span = laneWidth + laneGap
        guard span > 0 else { return 0 }

        let rel = x - lanesX0
        let idx = Int(floor(rel / span))
        return min(max(idx, 0), max(0, laneCount - 1))
    }
}

private struct GestureCaptureView: UIViewRepresentable {
    let onTap: (CGPoint) -> Void
    let onLongPressBegan: (CGPoint) -> Void
    let onLongPressChanged: (CGPoint) -> Void
    let onLongPressEnded: (CGPoint, CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true

        // Tap
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false

        // Long press (acts as press+drag selection)
        let lp = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        lp.minimumPressDuration = 0.3
        lp.allowableMovement = 12
        lp.cancelsTouchesInView = false

        // Prevent tap firing after a long press selection
        tap.require(toFail: lp)

        v.addGestureRecognizer(tap)
        v.addGestureRecognizer(lp)

        context.coordinator.view = v
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject {
        let parent: GestureCaptureView
        weak var view: UIView?

        private var startPoint: CGPoint?

        init(_ parent: GestureCaptureView) {
            self.parent = parent
        }

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let v = view else { return }
            let pt = gr.location(in: v)
            parent.onTap(pt)
        }

        @objc func handleLongPress(_ gr: UILongPressGestureRecognizer) {
            guard let v = view else { return }
            let pt = gr.location(in: v)

            switch gr.state {
            case .began:
                startPoint = pt
                parent.onLongPressBegan(pt)

            case .changed:
                parent.onLongPressChanged(pt)

            case .ended, .cancelled, .failed:
                let start = startPoint ?? pt
                parent.onLongPressEnded(start, pt)
                startPoint = nil

            default:
                break
            }
        }
    }
}

// MARK: - Interactive Activity Block (move + resize + clip markers)

private struct InteractiveActivityBlockView: View {
    let activity: Activity
    let dayStart: Date

    let clippedStart: Bool
    let clippedEnd: Bool

    let hourHeight: CGFloat
    let defaultDurationMinutes: Int

    // ✅ new: lane dragging inputs
    let currentLane: Int
    let laneCount: Int
    let laneWidth: CGFloat
    let laneGap: CGFloat

    let onEdit: () -> Void
    //let onCommitLane: (Int) -> Void
    let onCommitLaneChange: (Int, Int) -> Void
    
    let onHoverLane: (Int) -> Void
    let onEndHoverLane: () -> Void


    // Drag preview state
    @State private var isDragging = false
    @State private var dragDeltaMinutes: Int = 0
    @State private var dragDeltaLane: Int = 0

    @State private var isResizing = false
    @State private var resizeDeltaMinutes: Int = 0

    private let snapMinutes: Int = 5
    private let minDurationMinutes: Int = 15
    private let maxSpanDays: Int = 7

    var body: some View {
        let baseStart = rawStartMinute()
        let baseEnd = rawEndMinute()

        // Preview times while moving/resizing
        let previewStart = baseStart + dragDeltaMinutes
        let previewEnd = baseEnd + dragDeltaMinutes + resizeDeltaMinutes

        // Preview lane while dragging horizontally
        let laneSpan = laneWidth + laneGap
        let previewLane = clamp(currentLane + dragDeltaLane, 0, max(0, laneCount - 1))

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
                Text(isResizing ? "Resize" : "Move")
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
        // ✅ Move the view visually while lane-dragging
        .offset(x: CGFloat(previewLane - currentLane) * laneSpan)
        // Resize handle
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

    // MARK: - Gestures

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                isDragging = true

                // Vertical -> time move (only if event starts on this day; same rule you had)
                if canMoveInThisDay() {
                    dragDeltaMinutes = snap(minutesFromTranslation(value.translation.height))
                } else {
                    dragDeltaMinutes = 0
                }

                // Horizontal -> lane change preview
                let laneSpan = laneWidth + laneGap
                if laneSpan > 0 {
                    dragDeltaLane = Int((value.translation.width / laneSpan).rounded())
                } else {
                    dragDeltaLane = 0
                }
                //let laneSpan = laneWidth + laneGap
                let previewLane = clamp(currentLane + dragDeltaLane, 0, max(0, laneCount - 1))
                onHoverLane(previewLane)

            }
            .onEnded { value in
                // Compute final deltas
                let finalMinutes = canMoveInThisDay()
                    ? snap(minutesFromTranslation(value.translation.height))
                    : 0

                let laneSpan = laneWidth + laneGap
                let finalLaneDelta = (laneSpan > 0)
                    ? Int((value.translation.width / laneSpan).rounded())
                    : 0

                // Commit time move (if allowed)
                if finalMinutes != 0 {
                    commitMove(deltaMinutes: finalMinutes)
                }

                // Commit lane change (always allowed)
                if finalLaneDelta != 0 {
                    let newLane = clamp(currentLane + finalLaneDelta, 0, max(0, laneCount - 1))
                    onCommitLaneChange(currentLane, newLane)
                }
                
                onEndHoverLane()

                // Reset UI state
                isDragging = false
                dragDeltaMinutes = 0
                dragDeltaLane = 0
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

    // MARK: - Commits

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

    // MARK: - Helpers

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

private struct LaneHighlight: View {
    let x: CGFloat
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.tint.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.tint.opacity(0.10), lineWidth: 1)
            )
            .frame(width: width, height: height)
            .offset(x: x, y: 0)
            .allowsHitTesting(false)
    }
}

// MARK: - Layout (lane assignment respects activity.laneHint)

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

        // laneEnds[i] = end minute of last item in lane i
        var laneEnds: [Int] = []
        var out: [Item] = []
        out.reserveCapacity(segments.count)

        for s in segments {
            let preferred = max(0, s.activity.laneHint)

            // Ensure laneEnds has at least preferred+1 lanes (empty lanes end at 0 => free)
            if laneEnds.count <= preferred {
                laneEnds.append(contentsOf: Array(repeating: 0, count: preferred - laneEnds.count + 1))
            }

            var lane: Int? = nil

            // Try preferred lane first
            if laneEnds[preferred] <= s.start {
                lane = preferred
            } else {
                // Otherwise find any free lane
                for i in 0..<laneEnds.count {
                    if laneEnds[i] <= s.start {
                        lane = i
                        break
                    }
                }
            }

            // If none free, append a new lane
            if lane == nil {
                lane = laneEnds.count
                laneEnds.append(0)
            }

            let chosen = lane!
            laneEnds[chosen] = s.end

            out.append(
                Item(
                    activity: s.activity,
                    displayStartMinute: s.start,
                    displayEndMinute: s.end,
                    displayDurationMinutes: s.end - s.start,
                    lane: chosen,
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
