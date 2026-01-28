import SwiftUI
import SwiftData

// File: workouttracker/Features/Log/WorkoutLogScreen.swift
struct WorkoutLogScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    private let cal = Calendar.current

    // ✅ new: initial day to open with
    let initialSelectedDay: Date

    // ✅ initialize State from initialSelectedDay
    @State private var month: Date
    @State private var selectedDay: Date
    @State private var presentedSession: WorkoutSession? = nil

    /// Centralized display unit preference
    private var preferredUnit: WeightUnit { UnitPreferences.weightUnit }

    init(initialSelectedDay: Date = Date()) {
        self.initialSelectedDay = initialSelectedDay

        let cal = Calendar.current
        let day = cal.startOfDay(for: initialSelectedDay)
        let comps = cal.dateComponents([.year, .month], from: day)
        let monthStart = cal.date(from: comps) ?? day

        _selectedDay = State(initialValue: day)
        _month = State(initialValue: monthStart)
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader

            monthGrid

            Divider()

            daySummaryHeader

            historyLinkRow

            List {
                if sessionsForSelectedDay.isEmpty {
                    ContentUnavailableView(
                        "No workouts",
                        systemImage: "calendar.badge.minus",
                        description: Text("No sessions logged for this day.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(sessionsForSelectedDay) { s in
                        Button {
                            presentedSession = s
                        } label: {
                            WorkoutSessionRow(session: s)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding(.horizontal, 12)
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WorkoutHistoryScreen(
                        filter: .all,
                        onOpenSession: { s in presentedSession = s }
                    )
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("History")
            }
        }
        .task(id: cal.startOfDay(for: initialSelectedDay)) {
            let targetDay = cal.startOfDay(for: initialSelectedDay)
            if !cal.isDate(selectedDay, inSameDayAs: targetDay) {
                selectedDay = targetDay
            }
            if !cal.isDate(month, equalTo: targetDay, toGranularity: .month) {
                month = startOfMonth(targetDay)
            }
        }
        .onChange(of: month) { _, newMonth in
            // Keep selection inside the visible month
            let start = startOfMonth(newMonth)
            if !cal.isDate(selectedDay, equalTo: newMonth, toGranularity: .month) {
                selectedDay = start
            }
        }
        .navigationDestination(item: $presentedSession) { session in
            WorkoutSessionScreen(session: session)
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                month = addMonths(month, -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle(month))
                .font(.headline)

            Spacer()

            Button {
                month = addMonths(month, 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    // MARK: - Grid

    private var monthGrid: some View {
        let days = monthDays(for: month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        let weekdaySymbols = rotatedWeekdaySymbols()

        return VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    if let date = d {
                        DayCell(
                            date: date,
                            isSelected: cal.isDate(date, inSameDayAs: selectedDay),
                            isToday: cal.isDateInToday(date),
                            completedCount: completedSessionsByDay[cal.startOfDay(for: date)]?.count ?? 0
                        )
                        .onTapGesture {
                            selectedDay = cal.startOfDay(for: date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }

    // MARK: - Day Summary

    private var daySummaryHeader: some View {
        let (completed, total, volume, seconds) = dayMetrics(for: selectedDay)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dayTitle(selectedDay))
                    .font(.headline)

                Spacer()

                if cal.isDateInToday(selectedDay) {
                    Text("Today")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            HStack(spacing: 14) {
                StatChip(title: "Workouts", value: "\(completed)/\(total)")
                StatChip(title: "Volume (\(preferredUnit.label))", value: formatVolume(volume))
                StatChip(title: "Time", value: formatDuration(seconds))
            }
        }
        .padding(.horizontal, 2)
    }

    private var historyLinkRow: some View {
        HStack {
            NavigationLink {
                WorkoutHistoryScreen(
                    filter: .day(selectedDay),
                    onOpenSession: { s in presentedSession = s }
                )
            } label: {
                Label("History for this day", systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            Text("See all")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Derived data

    private var sessionsInVisibleMonth: [WorkoutSession] {
        sessions.filter { cal.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
    }

    private var sessionsByDay: [Date: [WorkoutSession]] {
        Dictionary(grouping: sessionsInVisibleMonth, by: { cal.startOfDay(for: $0.startedAt) })
    }

    private var completedSessionsByDay: [Date: [WorkoutSession]] {
        Dictionary(
            grouping: sessionsInVisibleMonth.filter { $0.status == .completed },
            by: { cal.startOfDay(for: $0.startedAt) }
        )
    }

    private var sessionsForSelectedDay: [WorkoutSession] {
        let key = cal.startOfDay(for: selectedDay)
        return (sessionsByDay[key] ?? []).sorted { $0.startedAt < $1.startedAt }
    }

    private func dayMetrics(for day: Date) -> (completed: Int, total: Int, volume: Double, seconds: Int) {
        let ss = sessionsForSelectedDay
        let total = ss.count
        let completed = ss.filter { $0.status == .completed }.count

        let pref = preferredUnit

        var volume: Double = 0
        var seconds: Int = 0

        for s in ss {
            seconds += s.elapsedSeconds(at: s.endedAt ?? Date())

            // Only count completed sets into volume (in preferred unit)
            for ex in s.exercises {
                for set in ex.setLogs where set.completed {
                    let reps = Double(set.reps ?? 0)
                    let w = set.weight(in: pref) ?? 0
                    volume += reps * w
                }
            }
        }

        return (completed, total, volume, seconds)
    }

    // MARK: - Date helpers

    private func startOfMonth(_ d: Date) -> Date {
        let comps = cal.dateComponents([.year, .month], from: d)
        return cal.date(from: comps) ?? d
    }

    private func addMonths(_ d: Date, _ delta: Int) -> Date {
        cal.date(byAdding: .month, value: delta, to: d) ?? d
    }

    private func monthTitle(_ d: Date) -> String {
        d.formatted(.dateTime.year().month(.wide))
    }

    private func dayTitle(_ d: Date) -> String {
        d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// Returns a grid of optional dates with leading/trailing nils to fill the month layout.
    private func monthDays(for month: Date) -> [Date?] {
        let first = startOfMonth(month)
        guard let range = cal.range(of: .day, in: .month, for: first) else { return [] }

        let firstWeekday = cal.component(.weekday, from: first)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7

        var out: [Date?] = Array(repeating: nil, count: leading)

        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: first) {
                out.append(date)
            }
        }

        while out.count % 7 != 0 { out.append(nil) }
        return out
    }

    private func rotatedWeekdaySymbols() -> [String] {
        let symbols = cal.shortWeekdaySymbols // Sunday-first
        let shift = cal.firstWeekday - 1      // convert to 0-based
        return Array(symbols[shift...] + symbols[..<shift])
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let r = m % 60
        return "\(h)h \(r)m"
    }

    private func formatVolume(_ v: Double) -> String {
        if v.rounded() == v { return "\(Int(v))" }
        return String(format: "%.1f", v)
    }
}

// MARK: - Small UI atoms

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let completedCount: Int

    var body: some View {
        let day = Calendar.current.component(.day, from: date)
        let dots = min(3, completedCount)

        VStack(spacing: 4) {
            Text("\(day)")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(maxWidth: .infinity)

            HStack(spacing: 3) {
                ForEach(0..<dots, id: \.self) { _ in
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundStyle(Color.accentColor)
                }
                if completedCount > 3 {
                    Text("+")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isToday ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    private var backgroundColor: Color {
        if isSelected { return Color.accentColor.opacity(0.14) }
        return Color.secondary.opacity(0.08)
    }
}

private struct WorkoutSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.sourceRoutineNameSnapshot ?? "Quick Workout")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let setsDone = session.exercises
                    .flatMap(\.setLogs)
                    .filter { $0.completed }
                    .count

                Text("\(setsDone) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusLabel: String {
        switch session.status {
        case .inProgress: return "In progress"
        case .completed: return "Completed"
        case .abandoned: return "Abandoned"
        }
    }

    private var timeRange: String {
        let start = session.startedAt.formatted(.dateTime.hour().minute())
        if let end = session.endedAt {
            return "\(start)–\(end.formatted(.dateTime.hour().minute()))"
        }
        return start
    }
}
