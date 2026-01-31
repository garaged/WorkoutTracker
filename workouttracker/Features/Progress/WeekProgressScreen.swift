import SwiftUI
import SwiftData

struct WeekProgressScreen: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var goalPrefill: GoalPrefillStore

    private let service = ProgressSummaryService()
    private let insightsService = ProgressInsightsService()
    private let quickStarter = QuickWorkoutStarterService()

    @State private var weeksBack: Int = 12
    @State private var summary: ProgressSummaryService.Summary? = nil
    @State private var insights: ProgressInsightsService.Summary? = nil
    @State private var loadError: String? = nil

    @State private var presentedSession: WorkoutSession? = nil
    @State private var startError: String? = nil
    
    @State private var pendingTarget: ProgressInsightsService.TargetCard? = nil
    @State private var resumeCandidate: WorkoutSession? = nil
    @State private var showResumeChoice: Bool = false


    var body: some View {
        Group {
            if let summary {
                List {
                    Section {
                        HStack {
                            StatChip(title: "Current streak", value: "\(summary.currentStreakDays)d")
                            StatChip(title: "Longest streak", value: "\(summary.longestStreakDays)d")
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        Picker("Window", selection: $weeksBack) {
                            Text("4w").tag(4)
                            Text("12w").tag(12)
                            Text("24w").tag(24)
                        }
                        .pickerStyle(.segmented)
                    }

                    if let insights {
                        Section("Insights") {
                            ProgressInsightsSectionView(
                                insights: insights,
                                onStartTarget: startFromTarget
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }

                    Section("Weeks") {
                        ForEach(summary.weeks) { w in
                            WeekRow(w: w)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else if let loadError {
                ContentUnavailableView(
                    "Couldn’t load progress",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView("Loading…")
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: weeksBack) { reload() }
        .refreshable { reload() }
        .navigationDestination(item: $presentedSession) { session in
            WorkoutSessionScreen(session: session)
                .onDisappear { presentedSession = nil }
        }
        .confirmationDialog(
            "Resume current workout?",
            isPresented: $showResumeChoice,
            titleVisibility: .visible
        ) {
            Button("Resume current workout") {
                showResumeChoice = false
                resumeRoutineAndApplyTarget()
                pendingTarget = nil
                resumeCandidate = nil
            }

            Button("Start Quick Workout") {
                showResumeChoice = false
                if let t = pendingTarget { startQuick(from: t) }
                pendingTarget = nil
                resumeCandidate = nil
            }

            Button("Cancel", role: .cancel) {
                showResumeChoice = false
                pendingTarget = nil
                resumeCandidate = nil
            }
        } message: {
            if let name = resumeCandidate?.sourceRoutineNameSnapshot {
                Text("You already have an in-progress workout (\(name)).")
            }
        }
        .alert("Couldn’t start workout", isPresented: Binding(
            get: { startError != nil },
            set: { if !$0 { startError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(startError ?? "")
        }
    }

    @MainActor
    private func reload() {
        do {
            summary = try service.summarize(weeksBack: weeksBack, context: modelContext)
            insights = try insightsService.summarize(weeksBack: weeksBack, context: modelContext)
            loadError = nil
        } catch {
            summary = nil
            insights = nil
            loadError = String(describing: error)
        }
    }

    @MainActor
    private func startFromTarget(_ t: ProgressInsightsService.TargetCard) {
        // If there's an in-progress non-Quick session, ask.
        if let routine = mostRecentInProgressNonQuickSession() {
            pendingTarget = t
            resumeCandidate = routine
            showResumeChoice = true
            return
        }

        // Otherwise, just start quick.
        startQuick(from: t)
    }
    
    @MainActor
    private func mostRecentInProgressNonQuickSession() -> WorkoutSession? {
        // Keep the dialog from appearing for ancient sessions:
        let now = Date()
        let window: TimeInterval = 8 * 60 * 60 // 8 hours

        var fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
        fd.fetchLimit = 10

        let sessions = (try? modelContext.fetch(fd)) ?? []
        return sessions.first(where: { s in
            s.status == .inProgress &&
            (s.sourceRoutineNameSnapshot ?? "") != QuickWorkoutStarterService.quickWorkoutName &&
            now.timeIntervalSince(s.startedAt) < window
        })
    }

    @MainActor
    private func startQuick(from t: ProgressInsightsService.TargetCard) {
        do {
            goalPrefill.set(GoalPrefillStore.Prefill(
                exerciseId: t.id,
                weight: t.targetWeight,
                reps: t.targetReps
            ))

            let session = try quickStarter.startOrReuseQuickSession(
                exerciseId: t.id,
                exerciseNameSnapshot: t.name,
                context: modelContext
            )
            presentedSession = session
        } catch {
            startError = String(describing: error)
        }
    }

    @MainActor
    private func resumeRoutineAndApplyTarget() {
        guard let t = pendingTarget, let s = resumeCandidate else { return }
        do {
            goalPrefill.set(GoalPrefillStore.Prefill(
                exerciseId: t.id,
                weight: t.targetWeight,
                reps: t.targetReps
            ))

            try quickStarter.prepareSessionForTarget(
                session: s,
                exerciseId: t.id,
                exerciseNameSnapshot: t.name,
                context: modelContext
            )
            presentedSession = s
        } catch {
            startError = String(describing: error)
        }
    }
}

private struct WeekRow: View {
    let w: ProgressSummaryService.WeekStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(weekTitle)
                    .font(.headline)
                Spacer()
                Text("\(w.workoutsCompleted) workouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                StatChip(title: "Sets", value: "\(w.totalSetsCompleted)")
                StatChip(title: "Volume", value: formatVolume(w.totalVolume))
                StatChip(title: "Time", value: formatDuration(w.timeTrainedSeconds))
            }
        }
        .padding(.vertical, 6)
    }

    private var weekTitle: String {
        let start = w.weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endInclusive = Calendar.current.date(byAdding: .day, value: -1, to: w.weekEndExclusive) ?? w.weekEndExclusive
        let end = endInclusive.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

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

