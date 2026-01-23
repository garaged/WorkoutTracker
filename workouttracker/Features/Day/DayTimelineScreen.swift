import SwiftData
import SwiftUI

struct DayTimelineScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [Activity]
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]
    @State private var isSelectingRange: Bool = false
    @State private var hoveredLaneWhileDraggingBlock: Int? = nil
    @StateObject private var autoScroll = AutoScrollController()
    @State private var viewportHeight: CGFloat = 0
    @State private var workoutActionActivity: Activity? = nil
    @State private var showWorkoutDialog: Bool = false
    @Binding var presentedSession: WorkoutSession?
    @State private var workoutLaunchState: WorkoutLaunchState = .none
    @State private var latestSessionByActivityIdCache: [UUID: WorkoutSession] = [:]
    @State private var suppressWorkoutTap = false


    private let day: Date
    private let cal = Calendar.current
    private var dayStart: Date { cal.startOfDay(for: day) }   // ✅ must use `day`, not Date()

    private let onEdit: (Activity) -> Void
    private let onCreateAt: (Date, Int) -> Void
    private let onCreateRange: (Date, Date, Int) -> Void

    // Layout knobs
    @AppStorage("timeline.hourHeight") private var hourHeightStored: Double = 80.0
    @State private var pinchBaseHourHeight: CGFloat? = nil

    private let minHourHeight: CGFloat = 48
    private let maxHourHeight: CGFloat = 180
    private let snapMinutes: Int = 5

    private var hourHeight: CGFloat { CGFloat(hourHeightStored) }

    private let gutterWidth: CGFloat = 58
    private let sidePadding: CGFloat = 12
    private let laneGap: CGFloat = 6


    private let defaultDurationMinutes: Int = 30

    init(
        day: Date,
        presentedSession: Binding<WorkoutSession?>,
        onEdit: @escaping (Activity) -> Void,
        onCreateAt: @escaping (Date, Int) -> Void,
        onCreateRange: @escaping (Date, Date, Int) -> Void
    ) {
        self.day = day
        self._presentedSession = presentedSession
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
        
        let sStart = Calendar.current.startOfDay(for: day)
        let sEnd = Calendar.current.date(byAdding: .day, value: 1, to: sStart)!

        _sessions = Query(
            filter: #Predicate<WorkoutSession> { s in
                s.startedAt >= sStart && s.startedAt < sEnd && s.linkedActivityId != nil
            },
            sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
    }

    var body: some View {
        let dayStart = Calendar.current.startOfDay(for: day)

        VStack(spacing: 0) {

            // ✅ New: fixed header above the scrollable grid
            DayHeaderActivitiesView(
                dayStart: dayStart,
                activities: activities,
                defaultDurationMinutes: defaultDurationMinutes,
                onSelect: { onTapActivity($0) }
            )
            .padding(.horizontal, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    timeline()
                        .padding(.horizontal, 8)
                        .padding(.bottom, 24)
                        .background(
                            ScrollViewIntrospector { sv in
                                autoScroll.attach(sv)
                            }
                        )
                }
                .simultaneousGesture(magnifyToZoomGesture)   // ✅ pinch zoom
                .coordinateSpace(name: "timelineViewport")


                // ✅ IMPORTANT: measure the actual scroll viewport (not the full screen)
                .background(
                    GeometryReader { svp in
                        Color.clear
                            .onAppear { viewportHeight = svp.size.height }
                            .onChange(of: svp.size.height) { _, newValue in
                                viewportHeight = newValue
                            }
                    }
                )

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
        .task(id: day.dayKey()) {
            do {
                try TemplatePreloader.ensureDayIsPreloaded(
                    for: day,
                    context: modelContext
                )
            } catch {
                print("Preload failed: \(error)")
            }
            refreshWorkoutSessionCache()
        }
        .confirmationDialog(
            workoutActionActivity?.title ?? "Workout",
            isPresented: $showWorkoutDialog,
            titleVisibility: .visible
        ) {
            if let a = workoutActionActivity {

                switch workoutLaunchState {
                case .none:
                    if a.workoutRoutineId == nil {
                        Button("Quick Start") { startQuickWorkout(from: a); closeWorkoutDialog() }
                        Button("Attach Routine") { onEdit(a); closeWorkoutDialog() }
                    } else {
                        Button("Start") { startWorkout(from: a); closeWorkoutDialog() }
                    }
                    Button("Edit Details") { onEdit(a); closeWorkoutDialog() }

                case .inProgress(let s):
                    Button("Open") { openSession(s); closeWorkoutDialog() }
                    Button(s.isPaused ? "Resume" : "Pause") {
                        togglePause(s)
                        closeWorkoutDialog()
                    }
                    Button("Finish") {
                        finishSession(s)
                        closeWorkoutDialog()
                    }
                    Button("Stop", role: .destructive) {
                        stopSession(s)
                        closeWorkoutDialog()
                    }
                    Button("Edit Details") { onEdit(a); closeWorkoutDialog() }

                case .completed(let s), .abandoned(let s):
                    Button("View Summary") { openSession(s); closeWorkoutDialog() }
                    Button("Start Again") { startSession(for: a); closeWorkoutDialog() }
                    Button("Edit Details") { onEdit(a); closeWorkoutDialog() }
                }

                Button("Delete", role: .destructive) { deleteActivity(a); closeWorkoutDialog() }
            }

            Button("Cancel", role: .cancel) { closeWorkoutDialog() }

        } message: {
            if let a = workoutActionActivity {
                switch workoutLaunchState {
                case .none:
                    Text(a.workoutRoutineId == nil
                         ? "No routine attached. Quick start or attach a routine."
                         : "Ready to start this routine.")
                case .inProgress(let s):
                    Text("In progress since \(s.startedAt.formatted(.dateTime.hour().minute())).")
                case .completed:
                    Text("Completed workout. View summary or start again.")
                case .abandoned:
                    Text("Abandoned workout. View summary or start again.")
                }
            } else {
                Text("")
            }
        }

    }

    private func timeline() -> some View {
        let dayStart = Calendar.current.startOfDay(for: day)
        let totalHeight = hourHeight * 24

        let buckets = DayActivityBucketer.bucket(
            activities: activities,
            dayStart: dayStart,
            defaultDurationMinutes: defaultDurationMinutes
        )
        let timedActivities = buckets.timed

        let laidOut = TimelineLayout.layout(
            activities: timedActivities,   // ✅ only timed go into the grid
            dayStart: dayStart,
            defaultDurationMinutes: defaultDurationMinutes
        )

        let laneByID: [PersistentIdentifier: Int] = Dictionary(
            uniqueKeysWithValues: laidOut.items.map {
                ($0.activity.persistentModelID, $0.lane)
            }
        )

        return GeometryReader { geo in
            let availableWidth = max(
                0,
                geo.size.width - gutterWidth - sidePadding * 2
            )
            let laneCount = max(1, laidOut.laneCount)
            let laneWidth =
                (availableWidth - laneGap * CGFloat(laneCount - 1))
                / CGFloat(laneCount)

            let lanesX0 = gutterWidth + sidePadding
            let laneSpan = laneWidth + laneGap

            ZStack(alignment: .topLeading) {
                // ✅ snap tick lines (only over the lanes area, not the gutter)
                TimelineTicksView(
                    totalMinutes: 24 * 60,
                    hourHeight: hourHeight,
                    snapMinutes: snapMinutes
                )
                .frame(width: max(0, geo.size.width - lanesX0), height: totalHeight)
                .offset(x: lanesX0, y: 0)

                
                TimelineGrid(hourHeight: hourHeight, gutterWidth: gutterWidth)
                    .frame(height: totalHeight)

                // Tap + press-drag selection (lane chosen by x coordinate)
                TimelineInteractionLayer(
                    totalHeight: totalHeight,
                    hourHeight: hourHeight,
                    snapMinutes: snapMinutes,
                    minDurationMinutes: 15,
                    laneCount: laneCount,
                    laneWidth: laneWidth,
                    laneGap: laneGap,
                    lanesX0: lanesX0,
                    isSelecting: $isSelectingRange,
                    autoScroll: autoScroll,
                    viewportHeight: viewportHeight,
                    onTap: { minute, lane in
                        let start = dateFromMinutes(minute, dayStart: dayStart)
                        onCreateAt(start, lane)
                    },
                    onDragRange: { startMin, endMin, lane in
                        let lo = min(startMin, endMin)
                        let hi = max(startMin, endMin)

                        let start = dateFromMinutes(lo, dayStart: dayStart)
                        let end   = dateFromMinutes(hi, dayStart: dayStart)

                        onCreateRange(start, end, lane)
                    }
                )
                .frame(height: totalHeight)

                // Now indicator
                if Calendar.current.isDateInToday(day) {
                    let nowMinutes = clampMinutes(
                        Int(Date().timeIntervalSince(dayStart) / 60)
                    )
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
                timelineContent(
                    laidOut: laidOut,
                    dayStart: dayStart,
                    timedActivities: timedActivities,
                    laneByID: laneByID,
                    laneCount: laneCount,
                    laneWidth: laneWidth,
                    lanesX0: lanesX0,
                    laneSpan: laneSpan
                )

            }
            .frame(height: totalHeight)
        }
        .frame(height: totalHeight)

    }

    // MARK: - Mapping
    private func onTapActivity(_ activity: Activity) {
        if activity.kind == .workout {
            handleWorkoutTap(activity)   // ✅ tap does the default action
            return
        }
        onEdit(activity)
    }

    // MARK: - Workout state + badge

    private func workoutSessionState(for activity: Activity) -> WorkoutLaunchState {
        guard let s = latestSessionByActivityIdCache[activity.id] else { return .none }
        switch s.status {
        case .inProgress: return .inProgress(s)
        case .completed:  return .completed(s)
        case .abandoned:  return .abandoned(s)
        }
    }
    
    @MainActor
    private func openSession(_ s: WorkoutSession) {
        // Use SwiftData's stable identity (safer than comparing `id` if your model changes)
        let same = presentedSession?.persistentModelID == s.persistentModelID

        if same {
            // Force SwiftUI to treat it as a "new" navigation by bouncing through nil
            presentedSession = nil
            Task { @MainActor in
                presentedSession = s
            }
        } else {
            presentedSession = s
        }
    }

    @MainActor
    private func refreshWorkoutSessionCache() {
        // Only care about visible workout activities
        let workoutIds = Set(activities.filter { $0.kind == .workout }.map(\.id))
        guard !workoutIds.isEmpty else {
            latestSessionByActivityIdCache = [:]
            return
        }

        do {
            // Fetch linked sessions once, then filter in memory
            let desc = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { s in s.linkedActivityId != nil },
                sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
            )
            let fetched = try modelContext.fetch(desc)

            var map: [UUID: WorkoutSession] = [:]
            for s in fetched {
                guard let aid = s.linkedActivityId, workoutIds.contains(aid) else { continue }
                if map[aid] == nil { map[aid] = s } // first wins (sorted desc)
            }
            latestSessionByActivityIdCache = map
        } catch {
            latestSessionByActivityIdCache = [:]
        }
    }
    
    @MainActor
    private func finishSessionFromTimeline(_ s: WorkoutSession, activity: Activity) {
        if s.isPaused { s.resume() }
        s.endedAt = Date()
        s.status = .completed

        // keep cache consistent for badges
        latestSessionByActivityIdCache[activity.id] = s

        do { try modelContext.save() }
        catch { assertionFailure("Failed to finish session: \(error)") }

        refreshWorkoutSessionCache()
    }
    
    @MainActor
    private func finishSession(_ s: WorkoutSession) {
        if s.isPaused { s.resume() }        // optional: avoid finishing while paused
        s.endedAt = Date()
        s.status = .completed

        do { try modelContext.save() }
        catch { assertionFailure("Failed to finish: \(error)") }

        refreshWorkoutSessionCache()
    }

    @MainActor
    private func abandonSessionFromTimeline(_ s: WorkoutSession, activity: Activity) {
        if s.isPaused { s.resume() }
        s.endedAt = Date()
        s.status = .abandoned

        latestSessionByActivityIdCache[activity.id] = s

        do { try modelContext.save() }
        catch { assertionFailure("Failed to abandon session: \(error)") }

        refreshWorkoutSessionCache()
    }
    
    @MainActor
    private func suppressWorkoutTapBriefly() {
        suppressWorkoutTap = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s is enough to swallow the "tap on release"
            suppressWorkoutTap = false
        }
    }
    
    private struct WorkoutStateBadge: View {
        let state: WorkoutLaunchState

        var body: some View {
            let (text, icon) = badgeSpec(state)

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(text)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(foregroundStyle(state))
            .allowsHitTesting(false)
        }

        private func badgeSpec(_ state: WorkoutLaunchState) -> (String, String) {
            switch state {
            case .none:              return ("Start", "play.circle")
            case .inProgress:        return ("Resume", "play.circle.fill")
            case .completed:         return ("Done", "checkmark.circle.fill")
            case .abandoned:         return ("Abandoned", "xmark.circle.fill")
            }
        }

        private func foregroundStyle(_ state: WorkoutLaunchState) -> some ShapeStyle {
            switch state {
            case .inProgress: return AnyShapeStyle(.tint)
            default:          return AnyShapeStyle(.secondary)
            }
        }
    }
    
    // Tap = do the default thing (NO dialog)
    private func handleWorkoutTap(_ activity: Activity) {
        guard !suppressWorkoutTap else { return }   // ✅ prevents “tap on release” after long press

        let state = workoutSessionState(for: activity)
        switch state {
        case .inProgress(let s), .completed(let s), .abandoned(let s):
            openSession(s) // or presentedSession = s (but openSession is better for re-nav)
        case .none:
            startSession(for: activity)
        }
    }

    // Long-press = show dialog
    private func showWorkoutActions(for activity: Activity) {
        suppressWorkoutTapBriefly()
        workoutActionActivity = activity
        workoutLaunchState = workoutSessionState(for: activity)
        showWorkoutDialog = true
    }
    
    private func yFromMinutes(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60.0) * hourHeight
    }

    private func heightFromMinutes(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60.0) * hourHeight
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }
    
    private func clampMinutes(_ m: Int) -> Int {
        min(max(m, 0), 24 * 60 - 1)
    }

    private func dateFromMinutes(_ minute: Int, dayStart: Date) -> Date {
        cal.date(byAdding: .minute, value: minute, to: dayStart) ?? dayStart
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

        let group = all.filter {
            overlaps($0, moved, defaultDurationMinutes: defaultDurationMinutes)
        }
        guard group.count > 1 else { return }

        var laneEnds = Array(repeating: Date.distantPast, count: lanes)

        func assign(_ a: Activity, _ lane: Int) {
            let l = clampLane(lane)
            a.laneHint = l
            laneEnds[l] = effectiveEnd(
                a,
                defaultDurationMinutes: defaultDurationMinutes
            )
        }

        // pin moved first
        assign(moved, pinnedLane)

        let others =
            group
            .filter { $0.persistentModelID != moved.persistentModelID }
            .sorted { $0.startAt < $1.startAt }

        for a in others {
            let s = a.startAt
            let preferred = clampLane(a.laneHint)
            let candidates =
                [preferred] + (0..<lanes).filter { $0 != preferred }

            var chosen: Int? = nil
            for l in candidates {
                if laneEnds[l] <= s {
                    chosen = l
                    break
                }
            }
            if chosen == nil {
                chosen =
                    laneEnds.enumerated().min(by: { $0.element < $1.element })?
                    .offset ?? 0
            }
            assign(a, chosen!)
        }
    }

    private func effectiveEnd(_ a: Activity, defaultDurationMinutes: Int)
        -> Date
    {
        a.endAt ?? Calendar.current.date(
            byAdding: .minute,
            value: defaultDurationMinutes,
            to: a.startAt
        )!
    }

    private func overlaps(
        _ a: Activity,
        _ b: Activity,
        defaultDurationMinutes: Int
    ) -> Bool {
        a.startAt
            < effectiveEnd(b, defaultDurationMinutes: defaultDurationMinutes)
            && b.startAt
                < effectiveEnd(
                    a,
                    defaultDurationMinutes: defaultDurationMinutes
                )
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
        let group = all.filter {
            overlaps($0, moved, defaultDurationMinutes: defaultDurationMinutes)
        }

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
                    && overlaps(
                        a,
                        other,
                        defaultDurationMinutes: defaultDurationMinutes
                    )
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

    private func commitTimeChange(
        moved: Activity,
        all: [Activity],
        defaultDurationMinutes: Int
    ) {
        // Build the connected overlap cluster containing `moved`
        let cluster = overlapCluster(
            containing: moved,
            all: all,
            defaultDurationMinutes: defaultDurationMinutes
        )

        guard cluster.count > 1 else {
            // If it's alone, normalize back to lane 0
            moved.laneHint = 0
            return
        }

        // Minimal-lane interval partitioning (ignores laneHint on purpose)
        let sorted = cluster.sorted {
            if $0.startAt != $1.startAt { return $0.startAt < $1.startAt }
            return effectiveEnd(
                $0,
                defaultDurationMinutes: defaultDurationMinutes
            )
                < effectiveEnd(
                    $1,
                    defaultDurationMinutes: defaultDurationMinutes
                )
        }

        var laneEnds: [Date] = []
        var assigned: [PersistentIdentifier: Int] = [:]
        assigned.reserveCapacity(sorted.count)

        for a in sorted {
            let s = a.startAt
            let e = effectiveEnd(
                a,
                defaultDurationMinutes: defaultDurationMinutes
            )

            var lane: Int? = nil
            for i in 0..<laneEnds.count {
                if laneEnds[i] <= s {
                    lane = i
                    break
                }
            }
            if lane == nil {
                lane = laneEnds.count
                laneEnds.append(e)
            } else {
                laneEnds[lane!] = e
            }

            assigned[a.persistentModelID] = lane!
        }

        // Persist lane hints so the order actually updates for everyone
        for a in cluster {
            a.laneHint = assigned[a.persistentModelID] ?? 0
        }
    }

    private func overlapCluster(
        containing moved: Activity,
        all: [Activity],
        defaultDurationMinutes: Int
    ) -> [Activity] {
        var seen: Set<PersistentIdentifier> = []
        var queue: [Activity] = [moved]
        seen.insert(moved.persistentModelID)

        while let cur = queue.popLast() {
            for a in all {
                let id = a.persistentModelID
                if seen.contains(id) { continue }
                if overlaps(
                    a,
                    cur,
                    defaultDurationMinutes: defaultDurationMinutes
                ) {
                    seen.insert(id)
                    queue.append(a)
                }
            }
        }

        return all.filter { seen.contains($0.persistentModelID) }
    }

    private var dayKey: String { day.dayKey() }  // or day.dayKey() if you have `day`

    private func deleteActivity(_ a: Activity) {
        if let templateId = a.templateId {
            modelContext.insert(
                TemplateInstanceOverride(
                    templateId: templateId,
                    dayKey: dayKey,
                    action: .deletedToday
                )
            )
        }
        modelContext.delete(a)
        try? modelContext.save()
    }

    private func skipToday(_ a: Activity) {
        guard let templateId = a.templateId else { return }
        modelContext.insert(
            TemplateInstanceOverride(
                templateId: templateId,
                dayKey: dayKey,
                action: .skippedToday
            )
        )
        a.status = .skipped
        try? modelContext.save()
    }

    private func toggleDone(_ a: Activity) {
        if a.status == .done {
            a.status = .planned
            a.completedAt = nil
        } else {
            a.status = .done
            a.completedAt = Date()
        }
        try? modelContext.save()
    }
    
    // Put this helper somewhere inside DayTimelineScreen
    private func isWorkout(_ a: Activity) -> Bool {
        a.kind == .workout || a.workoutRoutineId != nil || a.workoutSessionId != nil
    }
    
    @ViewBuilder
    private func timelineContent(
        laidOut: TimelineLayout.Result,
        dayStart: Date,
        timedActivities: [Activity],
        laneByID: [PersistentIdentifier: Int],
        laneCount: Int,
        laneWidth: CGFloat,
        lanesX0: CGFloat,
        laneSpan: CGFloat
    ) -> some View {
        ForEach(laidOut.items) { item in
            let a = item.activity
            let workout = isWorkout(a)

            let x = lanesX0 + CGFloat(item.lane) * laneSpan
            let y = yFromMinutes(item.displayStartMinute)
            let h = max(28, heightFromMinutes(item.displayDurationMinutes))

            // Base block
            let base = InteractiveActivityBlockView(
                activity: a,
                dayStart: dayStart,
                clippedStart: item.clippedStart,
                clippedEnd: item.clippedEnd,
                hourHeight: hourHeight,
                defaultDurationMinutes: defaultDurationMinutes,
                currentLane: item.lane,
                laneCount: laneCount,
                laneWidth: laneWidth,
                laneGap: laneGap,
                autoScroll: autoScroll,
                viewportHeight: viewportHeight,
                onEdit: {
                    if workout {
                        handleWorkoutTap(a)   // tap = push
                    } else {
                        onEdit(a)
                    }
                },
                onCommitLaneChange: { oldLane, newLane in
                    commitLaneChange(
                        moved: a,
                        oldLane: oldLane,
                        newLane: newLane,
                        all: timedActivities,
                        laneByID: laneByID,
                        maxLanes: laneCount,
                        defaultDurationMinutes: defaultDurationMinutes
                    )
                },
                onCommitTimeChange: {
                    commitTimeChange(
                        moved: a,
                        all: timedActivities,
                        defaultDurationMinutes: defaultDurationMinutes
                    )
                },
                onHoverLane: { lane in hoveredLaneWhileDraggingBlock = lane },
                onEndHoverLane: { hoveredLaneWhileDraggingBlock = nil }
            )

            // Decorate with badge (badge func can return nil for non-workouts)
            let decorated = base
                .overlay(alignment: .topTrailing) {
                    if item.activity.kind == .workout {
                        workoutOverlayControls(for: item.activity)
                            .padding(6)
                    }
                }

            // Important: apply gestures/menus in the conditional,
            // THEN apply frame/offset ONCE to the result.
            Group {
                if workout {
                    decorated
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showWorkoutActions(for: item.activity)
                        }
                } else {
                    decorated
                        .contextMenu {
                            Button { onEdit(a) } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button { toggleDone(a) } label: {
                                Label(
                                    a.isDone ? "Mark as not done" : "Mark as done",
                                    systemImage: a.isDone ? "arrow.uturn.left" : "checkmark"
                                )
                            }

                            if a.templateId != nil {
                                Button { skipToday(a) } label: {
                                    Label("Skip today", systemImage: "forward.end")
                                }
                            }

                            Divider()

                            Button(role: .destructive) { deleteActivity(a) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .frame(width: max(60, laneWidth), height: h, alignment: .topLeading)
            .offset(x: x, y: y)
        }
    }
    
    private func latestSession(for a: Activity) -> WorkoutSession? {
        latestSessionByActivityIdCache[a.id]
    }
    
    @ViewBuilder
    private func workoutOverlayControls(for a: Activity) -> some View {
        if let s = latestSession(for: a) {
            switch s.status {
            case .inProgress:
                HStack(spacing: 10) {
                    Button {
                        togglePause(s)
                    } label: {
                        Image(systemName: s.isPaused ? "play.fill" : "pause.fill")
                    }
                    .accessibilityLabel(s.isPaused ? "Resume workout" : "Pause workout")

                    Button(role: .destructive) {
                        stopSession(s)
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .accessibilityLabel("Stop workout")
                }
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .buttonStyle(.plain)

            case .completed, .abandoned:
                Button {
                    openSession(s)
                } label: {
                    Label("Summary", systemImage: "checkmark.circle")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                startSession(for: a)
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @MainActor
    private func togglePause(_ s: WorkoutSession) {
        if s.isPaused { s.resume() } else { s.pause() }
        try? modelContext.save()
        if let aid = s.linkedActivityId { latestSessionByActivityIdCache[aid] = s }
    }

    @MainActor
    private func stopSession(_ s: WorkoutSession) {
        // Treat "Stop" as "Finish" (Completed). Keep "Abandon" in your long-press menu.
        if s.isPaused { s.resume() }
        s.endedAt = Date()
        s.status = .completed
        try? modelContext.save()
        if let aid = s.linkedActivityId { latestSessionByActivityIdCache[aid] = s }
        openSession(s)
    }
    
    private var magnifyToZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if pinchBaseHourHeight == nil { pinchBaseHourHeight = hourHeight }

                let base = pinchBaseHourHeight ?? hourHeight
                let scaled = clamp(base * value, minHourHeight, maxHourHeight)

                hourHeightStored = Double(scaled)
            }
            .onEnded { _ in
                pinchBaseHourHeight = nil
            }
    }
    
    // MARK: - Workout session lookup / creation

    private enum WorkoutLaunchState {
        case none
        case inProgress(WorkoutSession)
        case completed(WorkoutSession)
        case abandoned(WorkoutSession)
    }

    private func mapSessionToState(_ s: WorkoutSession) -> WorkoutLaunchState {
        switch s.status {
        case .inProgress: return .inProgress(s)
        case .completed:  return .completed(s)
        case .abandoned:  return .abandoned(s)
        }
    }

    private func closeWorkoutDialog() {
        showWorkoutDialog = false
        workoutActionActivity = nil
    }

    private func startWorkout(from activity: Activity) {
        guard let routineId = activity.workoutRoutineId else {
            startQuickWorkout(from: activity)
            return
        }

        do {
            let desc = FetchDescriptor<WorkoutRoutine>(
                predicate: #Predicate { r in r.id == routineId }
            )
            guard let routine = try modelContext.fetch(desc).first else {
                assertionFailure("WorkoutRoutine not found for id=\(routineId)")
                startQuickWorkout(from: activity)
                return
            }

            let templates = WorkoutRoutineMapper.toExerciseTemplates(routine: routine)

            let session = WorkoutSessionFactory.makeSession(
                linkedActivityId: activity.id,
                sourceRoutineId: routine.id,
                sourceRoutineNameSnapshot: routine.name,
                exercises: templates,
                prefillActualsFromTargets: true
            )
            latestSessionByActivityIdCache[activity.id] = session

            modelContext.insert(session)

            // ✅ make sure the activity becomes “workout” and is linked
            activity.kind = .workout
            activity.workoutSessionId = session.id

            try modelContext.save()

            presentedSession = session      // ✅ now triggers push
            workoutLaunchState = .inProgress(session)
            workoutActionActivity = nil
        } catch {
            assertionFailure("Failed to start workout: \(error)")
            startQuickWorkout(from: activity)
        }
    }
    
    private func startQuickWorkout(from activity: Activity) {
        let session = WorkoutSessionFactory.makeSession(
            linkedActivityId: activity.id,
            sourceRoutineId: nil,
            sourceRoutineNameSnapshot: nil,
            exercises: [],
            prefillActualsFromTargets: true
        )

        latestSessionByActivityIdCache[activity.id] = session
        modelContext.insert(session)

        activity.kind = .workout
        activity.workoutSessionId = session.id

        do {
            try modelContext.save()
            openSession(session)
            workoutLaunchState = .inProgress(session)
            workoutActionActivity = nil
        } catch {
            assertionFailure("Failed to save quick session: \(error)")
        }
    }



    private func startSession(for activity: Activity) {
        if activity.workoutRoutineId == nil {
            startQuickWorkout(from: activity)
        } else {
            startWorkout(from: activity)
        }
    }
    
    private var workoutDialogTitle: String {
        workoutActionActivity?.title ?? "Workout"
    }

    private var workoutDialogMessage: String {
        guard let a = workoutActionActivity else { return "" }

        switch workoutLaunchState {
        case .none:
            if a.workoutRoutineId == nil {
                return "No routine attached. Quick Start now, or attach a routine."
            } else {
                return "Ready to start this workout."
            }

        case .inProgress(let s):
            let started = s.startedAt.formatted(.dateTime.hour().minute())
            return "In progress since \(started). Resume, restart, or edit details."

        case .completed(let s):
            let ended = (s.endedAt ?? s.startedAt).formatted(.dateTime.month(.abbreviated).day().hour().minute())
            return "Completed (\(ended)). View summary or start again."

        case .abandoned(let s):
            let ended = (s.endedAt ?? s.startedAt).formatted(.dateTime.month(.abbreviated).day().hour().minute())
            return "Abandoned (\(ended)). View summary or start again."
        }
    }

    private func clearWorkoutDialogState() {
        showWorkoutDialog = false
        workoutActionActivity = nil
    }

    private enum WorkoutBadge { case start, resume, paused, summary }

    private func workoutBadge(for a: Activity) -> WorkoutBadge? {
        guard a.kind == .workout else { return nil }
        
        guard let s = latestSessionByActivityIdCache[a.id] else {
            return .start
        }
        switch s.status {
        case .inProgress:
            return s.isPaused ? .paused : .resume
        case .completed, .abandoned:
            return .summary
        }
    }

    private struct WorkoutBadgeView: View {
        let badge: WorkoutBadge

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(text)
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }

        private var icon: String {
            switch badge {
            case .start:   return "play.circle"
            case .resume:  return "play.circle.fill"
            case .summary: return "checkmark.circle"
            case .paused: return "pause.circle.fill"
            }
        }

        private var text: String {
            switch badge {
            case .start:   return "Start"
            case .resume:  return "Resume"
            case .summary: return "Summary"
            case .paused: return "Paused"
            }
        }
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

    @ObservedObject var autoScroll: AutoScrollController
    let viewportHeight: CGFloat

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

                    // pt.y is CONTENT coordinates; convert to viewport Y for edge detection
                    let yViewport = pt.y - autoScroll.offsetY
                    autoScroll.updateDrag(
                        yInViewport: yViewport,
                        viewportHeight: viewportHeight
                    )

                    startY = clampY(pt.y)
                    currentY = clampY(pt.y)
                    selectedLane = laneForX(pt.x)
                },
                onLongPressChanged: { pt in
                    guard selecting else { return }

                    let yViewport = pt.y - autoScroll.offsetY
                    autoScroll.updateDrag(
                        yInViewport: yViewport,
                        viewportHeight: viewportHeight
                    )

                    currentY = clampY(pt.y)
                    selectedLane = laneForX(pt.x)
                },
                onLongPressEnded: { startPt, endPt in
                    defer {
                        selecting = false
                        isSelecting = false
                        autoScroll.stop()
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
        let snapped =
            Int((Double(raw) / Double(snapMinutes)).rounded()) * snapMinutes
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
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        
        // Long press (acts as press+drag selection)
        let lp = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
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
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // ✅ Refresh closures when SwiftUI updates this representable
        context.coordinator.parent = self
    }
    
    final class Coordinator: NSObject {
        var parent: GestureCaptureView   // ✅ must be mutable so it can refresh closures
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

        var segments:
            [(
                activity: Activity, start: Int, end: Int, clippedStart: Bool,
                clippedEnd: Bool
            )] = []
        segments.reserveCapacity(activities.count)

        for a in activities {
            let rawStart = Int(a.startAt.timeIntervalSince(dayStart) / 60)

            let endDate =
                a.endAt
                ?? Calendar.current.date(
                    byAdding: .minute,
                    value: defaultDurationMinutes,
                    to: a.startAt
                )!

            let rawEnd = Int(endDate.timeIntervalSince(dayStart) / 60)

            let clippedStart = rawStart < 0
            let clippedEnd = rawEnd > 24 * 60

            let clampedStart = clamp(rawStart)
            var clampedEnd = clamp(rawEnd)

            if clampedEnd <= clampedStart {
                clampedEnd = min(clampedStart + 15, 24 * 60)
            }

            segments.append(
                (a, clampedStart, clampedEnd, clippedStart, clippedEnd)
            )
        }

        segments.sort {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.end < $1.end
        }

        // 1) Compute max concurrency (how many lanes we truly need)
        // Process end events before start events at the same minute so [end==start] doesn't overlap.
        var events: [(t: Int, delta: Int)] = []
        events.reserveCapacity(segments.count * 2)

        for s in segments {
            events.append((s.start, +1))
            events.append((s.end, -1))
        }

        events.sort {
            if $0.t != $1.t { return $0.t < $1.t }
            return $0.delta < $1.delta  // -1 before +1
        }

        var cur = 0
        var maxConcurrent = 0
        for e in events {
            cur += e.delta
            if cur > maxConcurrent { maxConcurrent = cur }
        }

        let laneCount = max(1, maxConcurrent)

        // 2) Pre-create lanes so lane 1/2 exists even for earliest item (needed for “swap order”)
        var laneEnds = Array(repeating: 0, count: laneCount)

        var out: [Item] = []
        out.reserveCapacity(segments.count)

        // 3) Greedy assignment honoring laneHint (but never creating extra lanes beyond concurrency)
        for s in segments {
            let preferred = min(max(0, s.activity.laneHint), laneCount - 1)

            var chosen: Int? = nil

            // try preferred first
            if laneEnds[preferred] <= s.start {
                chosen = preferred
            } else {
                // else first free lane
                for i in 0..<laneCount {
                    if laneEnds[i] <= s.start {
                        chosen = i
                        break
                    }
                }
            }

            // With correct maxConcurrent, a lane should always exist; this is just a safety fallback.
            let lane = chosen ?? 0
            laneEnds[lane] = s.end

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

        return Result(items: out, laneCount: laneCount)
    }

    private static func clamp(_ m: Int) -> Int {
        min(max(m, 0), 24 * 60)
    }
}

extension TimelineLayout.Item: Identifiable {
    var id: UUID { activity.id }
}
