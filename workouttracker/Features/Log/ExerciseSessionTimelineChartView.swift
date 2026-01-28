// File: workouttracker/Features/Log/ExerciseSessionTimelineChartView.swift
import SwiftUI
import Charts

struct ExerciseSessionTimelineChartView: View {
    let points: [WorkoutHistoryService.ExerciseSessionPoint]
    let onSelectSessionId: (UUID) -> Void

    @State private var selectedDate: Date? = nil
    @State private var lastOpenedSessionId: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Timeline")
                    .font(.headline)
                Spacer()
                if let label = points.last?.label {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            if points.isEmpty {
                ContentUnavailableView(
                    "Not enough data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Complete a few sessions with this exercise to see a timeline.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                Chart(points) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Value", p.value)
                    )
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Value", p.value)
                    )
                }
                .frame(height: 170)
                .chartXSelection(value: $selectedDate)

                Text("Tap a point to open that session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            guard let d = newValue else { return }
            guard let nearest = nearestPoint(to: d) else { return }
            guard nearest.sessionId != lastOpenedSessionId else { return }

            lastOpenedSessionId = nearest.sessionId
            onSelectSessionId(nearest.sessionId)

            // Prevent double-triggering on small drags.
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    selectedDate = nil
                    lastOpenedSessionId = nil
                }
            }
        }
    }

    private func nearestPoint(to date: Date) -> WorkoutHistoryService.ExerciseSessionPoint? {
        points.min(by: { a, b in
            abs(a.date.timeIntervalSince(date)) < abs(b.date.timeIntervalSince(date))
        })
    }
}
