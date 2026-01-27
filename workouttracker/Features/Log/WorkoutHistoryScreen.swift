import SwiftUI
import SwiftData

struct WorkoutHistoryScreen: View {
    @Environment(\.modelContext) private var modelContext

    let onOpenSession: ((WorkoutSession) -> Void)?

    @State private var sessions: [WorkoutSession] = []
    @State private var loadError: String?

    private let history = WorkoutHistoryService()

    init(onOpenSession: ((WorkoutSession) -> Void)? = nil) {
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

            Section {
                ForEach(sessions, id: \.id) { s in
                    Button {
                        onOpenSession?(s)
                    } label: {
                        WorkoutHistoryRow(session: s)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Recent Workouts")
            }
        }
        .navigationTitle("History")
        .task { await reload() }
        .refreshable { await reload() }
    }

    @MainActor
    private func reload() async {
        do {
            loadError = nil
            sessions = try history.recentSessions(limit: 80, context: modelContext)
        } catch {
            sessions = []
            loadError = "History failed to load: \(error)"
        }
    }
}

private struct WorkoutHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                .font(.headline)

            Text("\(session.exercises.count) exercises")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let endedAt = session.endedAt {
                Text("Finished \(endedAt.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
