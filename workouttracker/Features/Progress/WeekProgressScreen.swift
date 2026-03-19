import SwiftUI
import SwiftData

struct WeekProgressScreen: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var goalPrefill: GoalPrefillStore

    private let service = ProgressSummaryService()
    private let insightsService = ProgressInsightsService()
    private let reflectionService = ReflectionInsightsService()
    private let quickStarter = QuickWorkoutStarterService()

    @State private var weeksBack: Int = 12
    @State private var summary: ProgressSummaryService.Summary? = nil
    @State private var insights: ProgressInsightsService.Summary? = nil
    @State private var reflectionSummary: ReflectionInsightsService.Summary? = nil
    @State private var loadError: String? = nil

    @State private var presentedSession: WorkoutSession? = nil
    @State private var startError: String? = nil
    
    @State private var pendingTarget: ProgressInsightsService.TargetCard? = nil
    @State private var resumeCandidate: WorkoutSession? = nil
    @State private var showResumeChoice: Bool = false

    /// If everything is 0 across the window, treat it as “no data yet”.
    /// This avoids the prototype-y feeling of a giant list of zeros.
    private var hasAnyProgressData: Bool {
        guard let summary else { return false }
        return summary.weeks.contains(where: { w in
            w.workoutsCompleted > 0 ||
            w.totalSetsCompleted > 0 ||
            w.totalVolume > 0 ||
            w.timeTrainedSeconds > 0
        })
    }


    var body: some View {
        Group {
            if let summary {
                List {
                    if hasAnyProgressData {
                        Section {
                            HStack {
                                StatChip(title: String(localized: "Current streak"), value: String(format: String(localized: "%lldd"), locale: .autoupdatingCurrent, Int64(summary.currentStreakDays)))
                                StatChip(title: String(localized: "Longest streak"), value: String(format: String(localized: "%lldd"), locale: .autoupdatingCurrent, Int64(summary.longestStreakDays)))
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section {
                        Picker(AppFormatting.localized("Window"), selection: $weeksBack) {
                            Text(AppFormatting.localized("4w")).tag(4)
                            Text(AppFormatting.localized("12w")).tag(12)
                            Text(AppFormatting.localized("24w")).tag(24)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel(AccessibilityLabels.Pickers.progressWindow)
                        .accessibilityHint(AccessibilityLabels.Pickers.progressWindowHint)
                    }

                    if hasAnyProgressData {
                        if let insights {
                            Section(AppFormatting.localized("Insights")) {
                                if let reflectionSummary {
                                    ReflectionRateInsightCard(summary: reflectionSummary)
                                }

                                ProgressInsightsSectionView(
                                    insights: insights,
                                    onStartTarget: startFromTarget
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            }
                        }

                        Section(AppFormatting.localized("Weeks")) {
                            ForEach(summary.weeks) { w in
                                WeekRow(w: w)
                            }
                        }
                    } else {
                        Section {
                            EmptyStateView(
                                title: AccessibilityLabels.EmptyStates.weekProgressTitle,
                                message: AccessibilityLabels.EmptyStates.weekProgressMessage,
                                systemImage: "chart.bar.xaxis"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
            } else if let loadError {
                ContentUnavailableView(AppFormatting.localized("Couldn’t load progress"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView(AppFormatting.localized("Loading…"))
            }
        }
        .navigationTitle(AppFormatting.localized("Progress"))
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
            Button(AppFormatting.localized("Resume current workout")) {
                showResumeChoice = false
                resumeRoutineAndApplyTarget()
                pendingTarget = nil
                resumeCandidate = nil
            }

            Button(AppFormatting.localized("Start Quick Workout")) {
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
                Text(AppFormatting.localizedFormat("You already have an in-progress workout (%@).", name))
            }
        }
        .alert(AppFormatting.localized("Couldn’t start workout"), isPresented: Binding(
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
            reflectionSummary = try reflectionService.summarize(weeksBack: weeksBack, context: modelContext)
            loadError = nil
        } catch {
            AppLogger.shared.error("WeekProgress reload failed: \(String(describing: error))", category: .persistence)
            summary = nil
            insights = nil
            reflectionSummary = nil
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
                Text(String(format: String(localized: "%lld workouts"), locale: .autoupdatingCurrent, Int64(w.workoutsCompleted)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                StatChip(title: String(localized: "Sets"), value: "\(w.totalSetsCompleted)")
                StatChip(title: String(localized: "Volume"), value: formatVolume(w.totalVolume))
                StatChip(title: String(localized: "Time"), value: formatDuration(w.timeTrainedSeconds))
            }
        }
        .padding(.vertical, 6)
    }

    private var weekTitle: String {
        let endInclusive = Calendar.current.date(byAdding: .day, value: -1, to: w.weekEndExclusive) ?? w.weekEndExclusive
        return AppFormatting.dateRange(start: w.weekStart, end: endInclusive)
    }

    private func formatDuration(_ seconds: Int) -> String {
        AppFormatting.shortDuration(seconds: seconds)
    }

    private func formatVolume(_ v: Double) -> String {
        if v.rounded() == v { return "\(Int(v))" }
        return String(format: "%.1f", v)
    }
}

// MARK: - Inline insight card

private struct ReflectionRateInsightCard: View {
    let summary: ReflectionInsightsService.Summary

    var body: some View {
        NavigationLink {
            ReflectionInsightsScreen()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppFormatting.localized("Reflections"))
                        .font(.subheadline.weight(.semibold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(rateText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        if summary.completedSessions == 0 {
            return String(localized: "Finish a workout to start stats")
        }
        return String(format: String(localized: "%lld/%lld sessions reflected"), locale: .autoupdatingCurrent, Int64(summary.sessionsWithReflection), Int64(summary.completedSessions))
    }

    private var rateText: String {
        guard let r = summary.reflectionRate else { return "—" }
        let pct = (r * 100).formatted(.number.precision(.fractionLength(0...0)))
        return "\(pct)%"
    }
}
