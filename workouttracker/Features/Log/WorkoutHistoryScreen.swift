// File: workouttracker/Features/Log/WorkoutHistoryScreen.swift
import SwiftUI
import SwiftData
import Charts

struct WorkoutHistoryScreen: View {
    enum Filter: Hashable {
        case all
        case day(Date)
        case exercise(exerciseId: UUID, exerciseName: String)
    }

    @Environment(\.modelContext) private var modelContext

    let filter: Filter
    let onOpenSession: ((WorkoutSession) -> Void)?

    @State private var sessions: [WorkoutSession] = []
    @State private var timelinePoints: [WorkoutHistoryService.ExerciseSessionPoint] = []
    @State private var loadError: String?
    @State private var searchText: String = ""

    // Premium controls
    @State private var completedOnly: Bool = true
    @State private var routineFilterName: String? = nil
    @State private var exerciseFilterId: UUID? = nil // only when filter == .all

    // Compare mode
    @State private var compareMode: Bool = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showCompareSheet: Bool = false

    // Fallback navigation if `onOpenSession` is nil
    @State private var presentedSession: WorkoutSession?
    
    // Inside WorkoutHistoryScreen

    private struct PushedExercise: Identifiable, Hashable {
        let id: UUID
        let name: String
    }

    @State private var pushedExercise: PushedExercise? = nil

    private let historyService = WorkoutHistoryService()
    private let calendar = Calendar.current

    init(filter: Filter = .all, onOpenSession: ((WorkoutSession) -> Void)? = nil) {
        self.filter = filter
        self.onOpenSession = onOpenSession
    }

    var body: some View {
        List {
            errorSection
            controlsSection
            exerciseEntrySection
            timelineSection
            sessionsSection
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search routines or exercises")
        .toolbar { toolbarContent }
        .task(id: reloadToken) { await reload() }
        .refreshable { await reload() }
        .safeAreaInset(edge: .bottom) { compareBar }
        .sheet(isPresented: $showCompareSheet) { compareSheet }
        .navigationDestination(item: $presentedSession) { s in
            WorkoutSessionScreen(session: s)
        }
        .navigationDestination(item: $pushedExercise) { ex in
            WorkoutHistoryScreen(filter: .exercise(exerciseId: ex.id, exerciseName: ex.name), onOpenSession: onOpenSession)
        }
        .onChange(of: selectedIds) { _, _ in
            guard compareMode else { return }
            if selectedIds.count == 2 { showCompareSheet = true }
        }
        .onChange(of: compareMode) { _, on in
            if !on { selectedIds.removeAll() }
        }
    }

    // MARK: - Title

    private var title: String {
        switch filter {
        case .all: return "History"
        case .day(let d): return d.formatted(.dateTime.month(.abbreviated).day().year())
        case .exercise(_, let name): return "\(name) History"
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var errorSection: some View {
        if let loadError {
            Section {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var controlsSection: some View {
        Section {
            Toggle("Completed only", isOn: $completedOnly)

            routinePickerRow

            if case .all = filter {
                exercisePickerRow
            }

            if compareMode {
                Text("Select 2 sessions to compare.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: completedOnly) { _, _ in
            Task { await reload() }
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        // Use the shared chart view you already have in the project:
        // ExerciseSessionTimelineChartView(points:onSelectSessionId:)
        if case .exercise = filter, !timelinePoints.isEmpty {
            Section("Timeline") {
                ExerciseSessionTimelineChartView(
                    points: timelinePoints,
                    onSelectSessionId: { sessionId in
                        Task { await openSessionById(sessionId) }
                    }
                )
                .frame(height: 220)
            }
        }
    }

    @ViewBuilder
    private var sessionsSection: some View {
        if groupedDays.isEmpty, loadError == nil {
            Section {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock",
                    description: Text("Complete workouts to see them here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        } else {
            ForEach(groupedDays, id: \.day) { group in
                Section(group.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())) {
                    ForEach(group.sessions) { s in
                        sessionRow(s)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exerciseEntrySection: some View {
        if case .all = filter {
            let items = exerciseBrowseItems(search: searchText)

            Section("Exercises") {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No exercises yet",
                        systemImage: "dumbbell",
                        description: Text("Complete a workout to populate exercises here.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else {
                    ForEach(items) { ex in
                        Button {
                            pushedExercise = ex
                        } label: {
                            HStack {
                                Text(ex.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                compareMode.toggle()
            } label: {
                Image(systemName: compareMode ? "checkmark.circle" : "square.split.2x1")
            }

            if compareMode {
                Button("Clear") { selectedIds.removeAll() }
            }
        }
    }

    // MARK: - Compare bar + sheet

    @ViewBuilder
    private var compareBar: some View {
        if compareMode {
            let canCompare = selectedIds.count == 2

            HStack(spacing: 10) {
                Button("Cancel") { compareMode = false }
                    .buttonStyle(.bordered)

                Spacer()

                Button {
                    showCompareSheet = true
                } label: {
                    Label("Compare", systemImage: "rectangle.split.2x1")
                }
                .disabled(!canCompare)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var compareSheet: some View {
        let picked = sessions
            .filter { selectedIds.contains($0.id) }
            .sorted { $0.startedAt > $1.startedAt }

        if picked.count == 2 {
            WorkoutSessionCompareSheet(a: picked[0], b: picked[1])
        } else {
            VStack(spacing: 12) {
                Text("Pick 2 sessions to compare.")
                    .foregroundStyle(.secondary)
                Button("Close") { showCompareSheet = false }
            }
            .padding()
        }
    }

    // MARK: - Pickers

    private var routineOptions: [String] {
        let names = sessions.map { $0.sourceRoutineNameSnapshot ?? "Quick Workout" }
        return Array(Set(names)).sorted()
    }

    private var exerciseOptions: [(id: UUID, name: String)] {
        var dict: [UUID: String] = [:]
        for s in sessions {
            for ex in s.exercises {
                dict[ex.exerciseId] = ex.exerciseNameSnapshot
            }
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.name < $1.name }
    }

    private var routinePickerRow: some View {
        HStack {
            Text("Routine")
            Spacer()
            Picker("", selection: Binding(
                get: { routineFilterName ?? "__ALL__" },
                set: { routineFilterName = ($0 == "__ALL__") ? nil : $0 }
            )) {
                Text("All").tag("__ALL__")
                ForEach(routineOptions, id: \.self) { n in
                    Text(n).tag(n)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var exercisePickerRow: some View {
        HStack {
            Text("Exercise")
            Spacer()
            Picker("", selection: $exerciseFilterId) {
                Text("All").tag(UUID?.none)
                ForEach(exerciseOptions, id: \.id) { opt in
                    Text(opt.name).tag(Optional(opt.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    // MARK: - Row rendering

    @ViewBuilder
    private func sessionRow(_ s: WorkoutSession) -> some View {
        if compareMode {
            Button {
                toggleSelection(s.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedIds.contains(s.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIds.contains(s.id) ? Color.accentColor : Color.secondary)

                    WorkoutHistoryRow(session: s)
                }
            }
            .buttonStyle(.plain)
        } else {
            Button {
                openSession(s)
            } label: {
                WorkoutHistoryRow(session: s)
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            if selectedIds.count >= 2 {
                selectedIds = [id] // replace selection
            } else {
                selectedIds.insert(id)
            }
        }
    }

    private func openSession(_ s: WorkoutSession) {
        if let onOpenSession {
            onOpenSession(s)
        } else {
            presentedSession = s
        }
    }

    @MainActor
    private func openSessionById(_ sessionId: UUID) async {
        if let found = sessions.first(where: { $0.id == sessionId }) {
            openSession(found)
            return
        }

        // Fallback: fetch directly (avoids requiring a `session(id:)` method in the service)
        let sid = sessionId
        do {
            var fd = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate<WorkoutSession> { s in s.id == sid }
            )
            fd.fetchLimit = 1
            if let fetched = try modelContext.fetch(fd).first {
                openSession(fetched)
            }
        } catch {
            // ignore tap failures
        }
    }

    // MARK: - Filtering + grouping

    private var filteredSessions: [WorkoutSession] {
        var out = sessions

        if completedOnly {
            out = out.filter { $0.status == .completed }
        }

        if let routineFilterName {
            out = out.filter { ($0.sourceRoutineNameSnapshot ?? "Quick Workout") == routineFilterName }
        }

        if case .all = filter, let exId = exerciseFilterId {
            out = out.filter { s in
                s.exercises.contains(where: { $0.exerciseId == exId })
            }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return out }

        return out.filter { s in
            let routine = (s.sourceRoutineNameSnapshot ?? "Quick Workout").lowercased()
            if routine.contains(q) { return true }
            return s.exercises.contains(where: { $0.exerciseNameSnapshot.lowercased().contains(q) })
        }
    }

    private var groupedDays: [(day: Date, sessions: [WorkoutSession])] {
        let dict = Dictionary(grouping: filteredSessions) { s in
            calendar.startOfDay(for: s.startedAt)
        }
        return dict
            .map { (day: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.day > $1.day }
    }

    // MARK: - Reload

    private var reloadToken: String {
        "\(filter)|\(completedOnly)"
    }

    @MainActor
    private func reload() async {
        do {
            loadError = nil

            let includeIncomplete = !completedOnly

            switch filter {
            case .all:
                sessions = try historyService.recentSessions(limit: 200, includeIncomplete: includeIncomplete, context: modelContext)
                timelinePoints = []

            case .day(let d):
                sessions = try historyService.sessions(on: d, includeIncomplete: includeIncomplete, context: modelContext)
                timelinePoints = []

            case .exercise(let exerciseId, _):
                sessions = try historyService.sessions(containing: exerciseId, limit: 200, includeIncomplete: includeIncomplete, context: modelContext)
                timelinePoints = try historyService.exerciseTimeline(exerciseId: exerciseId, limit: 40, includeIncomplete: includeIncomplete, context: modelContext)
            }

            // Clear invalid menu selections
            if let rf = routineFilterName, !routineOptions.contains(rf) {
                routineFilterName = nil
            }
            if case .all = filter, let exId = exerciseFilterId {
                if !exerciseOptions.contains(where: { $0.id == exId }) {
                    exerciseFilterId = nil
                }
            }

        } catch {
            sessions = []
            timelinePoints = []
            loadError = "History failed to load: \(error)"
        }
    }
    // MARK: Derived data
    private struct ExerciseBrowseItem: Identifiable, Hashable {
        let id: UUID
        let name: String
        let sessionsCount: Int
    }

    // File: workouttracker/Features/Log/WorkoutHistoryScreen.swift
    private func exerciseBrowseItems(search: String) -> [PushedExercise] {
        // Build from already-loaded sessions (fast, no extra SwiftData query)
        var counts: [UUID: (name: String, count: Int)] = [:]

        for s in sessions {
            // count each exercise at most once per session
            var seenInSession = Set<UUID>()
            for ex in s.exercises {
                guard !seenInSession.contains(ex.exerciseId) else { continue }
                seenInSession.insert(ex.exerciseId)

                let cur = counts[ex.exerciseId]?.count ?? 0
                counts[ex.exerciseId] = (name: ex.exerciseNameSnapshot, count: cur + 1)
            }
        }

        var items = counts.map { (id: $0.key, name: $0.value.name, count: $0.value.count) }
        items.sort {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.name < $1.name
        }

        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter { $0.name.lowercased().contains(q) }
        }

        // Keep it tight so History feels curated
        return items.prefix(30).map { PushedExercise(id: $0.id, name: $0.name) }
    }
}

// MARK: - Row UI (defined in this file so it always exists)

private struct WorkoutHistoryRow: View {
    let session: WorkoutSession
    private var preferredUnit: WeightUnit { UnitPreferences.weightUnit }

    var body: some View {
        let stats = summarize(session)
        let title = session.sourceRoutineNameSnapshot ?? "Quick Workout"

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
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

                Text("\(stats.exercises) exercises • \(stats.sets) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if stats.volume > 0 {
                Text("Volume: \(stats.volume.formatted(.number.precision(.fractionLength(0)))) \(preferredUnit.label)·reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let duration = stats.durationText {
                Text("Duration: \(duration)")
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

    private struct Stats {
        let exercises: Int
        let sets: Int
        let volume: Double
        let durationText: String?
    }

    private func summarize(_ s: WorkoutSession) -> Stats {
        let exercisesCount = s.exercises.count
        let completedSets = s.exercises.flatMap(\.setLogs).filter { $0.completed }

        let setsCount = completedSets.count
        let pref = preferredUnit
        let volume = completedSets.reduce(0.0) { acc, log in
            let w = log.weight(in: pref) ?? 0
            let r = Double(log.reps ?? 0)
            return acc + (w * r)
        }


        let durationText: String?
        if let end = s.endedAt {
            let secs = max(0, Int(end.timeIntervalSince(s.startedAt)))
            durationText = formatDuration(secs)
        } else {
            durationText = nil
        }

        return Stats(exercises: exercisesCount, sets: setsCount, volume: volume, durationText: durationText)
    }

    private func formatDuration(_ secs: Int) -> String {
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
    
}
