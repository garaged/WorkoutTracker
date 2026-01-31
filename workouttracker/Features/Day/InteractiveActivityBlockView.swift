import SwiftData
import SwiftUI

// File: workouttracker/Features/Day/InteractiveActivityBlockView.swift
//
// What this view is responsible for:
// - Rendering one timeline "block" for an Activity
// - Allowing vertical drag to move time, horizontal drag to change lane
// - Allowing drag on the bottom-right handle to resize ONLY (end time)
// - Delegating action menus to the parent via `onMoreActions`
//
// IMPORTANT DESIGN CHOICE:
// We intentionally attach the move-drag gesture only to the main content layer,
// and keep the resize handle as a separate sibling overlay.
// This prevents the resize drag from also triggering the move drag (your current bug).

struct InteractiveActivityBlockView: View {
    let activity: Activity
    let dayStart: Date

    let clippedStart: Bool
    let clippedEnd: Bool

    let hourHeight: CGFloat
    let defaultDurationMinutes: Int

    // Lane dragging inputs
    let currentLane: Int
    let laneCount: Int
    let laneWidth: CGFloat
    let laneGap: CGFloat

    @ObservedObject var autoScroll: AutoScrollController
    let viewportHeight: CGFloat

    let onEdit: () -> Void
    let onMoreActions: () -> Void
    let onCommitLaneChange: (Int, Int) -> Void
    let onCommitTimeChange: () -> Void

    let onHoverLane: (Int) -> Void
    let onEndHoverLane: () -> Void

    // Drag preview state
    @State private var isDragging = false
    @State private var dragDeltaMinutes: Int = 0
    @State private var dragDeltaLane: Int = 0

    @State private var dragStartContentY: CGFloat? = nil
    @State private var resizeStartContentY: CGFloat? = nil

    @State private var isResizing = false
    @State private var resizeDeltaMinutes: Int = 0

    // Snap/haptics polish
    private let snapMinutes: Int = 5
    @State private var lastMoveSnappedDelta: Int? = nil
    @State private var lastResizeSnappedDelta: Int? = nil

    // Prevent the main tap from firing after tapping the handle.
    @State private var ignoreNextEditTap = false

    private let minDurationMinutes: Int = 15
    private let maxSpanDays: Int = 7

    var body: some View {
        // Base times
        let baseStart = rawStartMinute()
        let baseEnd = rawEndMinute()

        // Preview times while moving/resizing
        let previewStart = baseStart + dragDeltaMinutes
        let previewEnd = baseEnd + dragDeltaMinutes + resizeDeltaMinutes

        // Preview lane while dragging horizontally
        let laneSpan = laneWidth + laneGap
        let previewLane = clamp(
            currentLane + dragDeltaLane,
            0,
            max(0, laneCount - 1)
        )

        let previewClippedStart = previewStart < 0
        let previewClippedEnd = previewEnd > 24 * 60

        let timeLabel = "\(formatTime(previewStart)) – \(formatTime(previewEnd))"

        // Main visual content (this is what gets the MOVE gesture)
        let content =
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
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.tint.opacity(0.35), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isDragging || isResizing {
                Text(isResizing ? "Resize" : "Move")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .allowsHitTesting(false)
                    .padding(8)
            }
        }
        .overlay(alignment: .topLeading) {
            if clippedStart || previewClippedStart {
                ClipMarker(systemName: "chevron.up")
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if clippedEnd || previewClippedEnd {
                ClipMarker(systemName: "chevron.down")
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if activity.templateId != nil {
                TemplateBadgeView()
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        // Move the view visually while lane-dragging
        .offset(x: CGFloat(previewLane - currentLane) * laneSpan)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        // ✅ IMPORTANT: Move gesture is applied ONLY to the content layer
        .gesture(moveGesture, including: .gesture)
        .onTapGesture {
            if ignoreNextEditTap {
                ignoreNextEditTap = false
                return
            }
            if !isDragging && !isResizing { onEdit() }
        }

        // Compose: content + handle sibling
        return ZStack(alignment: .bottomTrailing) {
            content

            // Bottom-right handle:
            // - Drag: resize only
            // - Tap: open parent action menu (workout menu OR activity menu)
            moreHandle
                .padding(8)
                .contentShape(Rectangle())
                .highPriorityGesture(resizeGesture) // drag = resize
                .simultaneousGesture(
                    TapGesture().onEnded {
                        ignoreNextEditTap = true
                        onMoreActions()
                    }
                )
        }
    }

    private var moreHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Activity actions (drag to resize)")
    }

    // MARK: - Gestures

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("timelineViewport"))
            .onChanged { value in
                // If resize is active, do nothing.
                // (This is a secondary guard; the main prevention is the handle being a sibling.)
                if isResizing { return }

                isDragging = true

                autoScroll.updateDrag(
                    yInViewport: value.location.y,
                    viewportHeight: viewportHeight
                )

                let contentY = autoScroll.offsetY + value.location.y
                if dragStartContentY == nil { dragStartContentY = contentY }

                let dy = contentY - (dragStartContentY ?? contentY)

                if canMoveInThisDay() {
                    let snapped = snap(minutesFromTranslation(dy))
                    if let last = lastMoveSnappedDelta, last != snapped {
                        Haptics.tickLight()
                    }
                    lastMoveSnappedDelta = snapped
                    dragDeltaMinutes = snapped
                } else {
                    dragDeltaMinutes = 0
                    lastMoveSnappedDelta = nil
                }

                let laneSpan = laneWidth + laneGap
                if laneSpan > 0 {
                    dragDeltaLane = Int((value.translation.width / laneSpan).rounded())
                } else {
                    dragDeltaLane = 0
                }

                let previewLane = clamp(
                    currentLane + dragDeltaLane,
                    0,
                    max(0, laneCount - 1)
                )
                onHoverLane(previewLane)
            }
            .onEnded { value in
                let endContentY = autoScroll.offsetY + value.location.y
                let startContentY = dragStartContentY ?? endContentY
                let dy = endContentY - startContentY

                let finalMinutes = canMoveInThisDay()
                    ? snap(minutesFromTranslation(dy))
                    : 0

                let laneSpan = laneWidth + laneGap
                let finalLaneDelta = (laneSpan > 0)
                    ? Int((value.translation.width / laneSpan).rounded())
                    : 0

                if finalMinutes != 0 {
                    commitMove(deltaMinutes: finalMinutes)
                }

                if finalLaneDelta != 0 {
                    let newLane = clamp(
                        currentLane + finalLaneDelta,
                        0,
                        max(0, laneCount - 1)
                    )
                    onCommitLaneChange(currentLane, newLane)
                } else if finalMinutes != 0 {
                    onCommitTimeChange()
                }

                onEndHoverLane()
                autoScroll.stop()

                isDragging = false
                dragDeltaMinutes = 0
                dragDeltaLane = 0
                dragStartContentY = nil
                lastMoveSnappedDelta = nil
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("timelineViewport"))
            .onChanged { value in
                // When resizing starts, we mark isResizing so the move gesture ignores updates.
                isResizing = true

                autoScroll.updateDrag(
                    yInViewport: value.location.y,
                    viewportHeight: viewportHeight
                )

                let contentY = autoScroll.offsetY + value.location.y
                if resizeStartContentY == nil { resizeStartContentY = contentY }

                let dy = contentY - (resizeStartContentY ?? contentY)
                let snapped = snap(minutesFromTranslation(dy))

                if let last = lastResizeSnappedDelta, last != snapped {
                    Haptics.tickLight()
                }
                lastResizeSnappedDelta = snapped

                resizeDeltaMinutes = snapped
            }
            .onEnded { value in
                let endContentY = autoScroll.offsetY + value.location.y
                let startContentY = resizeStartContentY ?? endContentY
                let dy = endContentY - startContentY

                let delta = snap(minutesFromTranslation(dy))
                commitResize(deltaMinutes: delta)
                onCommitTimeChange()

                autoScroll.stop()

                isResizing = false
                resizeDeltaMinutes = 0
                resizeStartContentY = nil
                lastResizeSnappedDelta = nil
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
        let endDate =
            activity.endAt
            ?? Calendar.current.date(
                byAdding: .minute,
                value: defaultDurationMinutes,
                to: activity.startAt
            )!
        return Int(endDate.timeIntervalSince(dayStart) / 60)
    }

    private func normalizedDurationMinutes() -> Int {
        max(minDurationMinutes, rawEndMinute() - rawStartMinute())
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
