import SwiftUI
import SwiftData

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
    @State private var loadError: String?
    @State private var searchText: String = ""

    private let historyService = WorkoutHistoryService()
    private let calendar = Calendar.current

    init(filter: Filter = .all, onOpenSession: ((WorkoutSession) -> Void)? = nil) {
        self.filter = filter
        self.onOpenSession = onOpenSession
    }

    var body: some View {
        List {
            if let loadError {
                Section {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(groupedDays, id: \.day) { group in
                Section(group.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())) {
                    ForEach(group.sessions, id: \.id) { s in
                        if let onOpenSession {
                            Button { onOpenSession(s) } label: {
                                WorkoutHistoryRow(session: s)
                            }
                            .buttonStyle(.plain)
                        } else {
                            WorkoutHistoryRow(session: s)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .task(id: filter) { await reload() }
        .refreshable { await reload() }
        .searchable(text: $searchText, prompt: "Search workouts or exercises")
    }

    private var title: String {
        switch filter {
        case .all: return "History"
        case .day(let d): return d.formatted(.dateTime.month(.abbreviated).day().year())
        case .exercise(_, let name): return "\(name) History"
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

    private var filteredSessions: [WorkoutSession] {
        let base = sessions
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }

        return base.filter { s in
            let routine = (s.sourceRoutineNameSnapshot ?? "Quick Workout").lowercased()
            if routine.contains(q) { return true }
            return s.exercises.contains(where: { $0.exerciseNameSnapshot.lowercased().contains(q) })
        }
    }

    @MainActor
    private func reload() async {
        do {
            loadError = nil
            switch filter {
            case .all:
                sessions = try historyService.recentSessions(limit: 120, includeIncomplete: true, context: modelContext)
            case .day(let d):
                sessions = try historyService.sessions(on: d, includeIncomplete: true, context: modelContext)
            case .exercise(let exerciseId, _):
                sessions = try historyService.sessions(containing: exerciseId, limit: 120, includeIncomplete: true, context: modelContext)
            }
        } catch {
            sessions = []
            loadError = "History failed to load: \(error)"
        }
    }
}

private struct WorkoutHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        let stats = summarize(session)
        let title = session.sourceRoutineNameSnapshot ?? "Quick Workout"
        let exercisePreview = previewExercises(session)

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

            if !exercisePreview.isEmpty {
                Text(exercisePreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if stats.volume > 0 {
                Text("Volume: \(stats.volume.formatted(.number.precision(.fractionLength(0))))")
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

    private func previewExercises(_ s: WorkoutSession) -> String {
        let names = s.exercises.map(\.exerciseNameSnapshot)
        let shown = names.prefix(3)
        let more = max(0, names.count - shown.count)
        if more > 0 {
            return shown.joined(separator: " • ") + " • +\(more)"
        }
        return shown.joined(separator: " • ")
    }

    private struct Stats {
        let exercises: Int
        let sets: Int
        let volume: Double
        let durationText: String?
    }

    private func summarize(_ s: WorkoutSession) -> Stats {
        let exercisesCount = s.exercises.count

        let allSets = s.exercises.flatMap { $0.setLogs }
        let completedSets = allSets.filter { $0.completed }

        let setsCount = completedSets.count
        let volume = completedSets.reduce(0.0) { acc, log in
            guard let w = log.weight, let r = log.reps, w > 0, r > 0 else { return acc }
            return acc + (w * Double(r))
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
