import SwiftUI
import SwiftData
import Charts
import UIKit

@MainActor
struct WorkoutSessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goalPrefill: GoalPrefillStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass


    @Bindable var session: WorkoutSession

    @StateObject private var logging = WorkoutLoggingService()
    @StateObject private var prefs = UserPreferences.shared
    @ObservedObject private var restTimer = SessionRestTimerController.shared

    /// Display numbering for set rows.
    ///
    /// Historically some builders stored `WorkoutSetLog.order` as 0-based (0,1,2,...) while
    /// others stored it as 1-based (1,2,3,...). The UI should always show sets starting at 1.
    ///
    /// We detect the base per-exercise by looking at the minimum order in that exercise.
    private func displaySetNumber(for set: WorkoutSetLog, in ex: WorkoutSessionExercise) -> Int {
        let ordered = sortedSets(for: ex)
        guard let index = ordered.firstIndex(where: { $0.id == set.id }) else {
            return max(1, set.order + 1)
        }
        return index + 1
    }

    @State private var showFinishConfirm = false
    @State private var showAbandonConfirm = false
    @State private var showRestTimer = false
    @State private var activeExerciseID: UUID? = nil
    @State private var activeSetID: UUID? = nil
    @State private var skippedSegmentKinds: Set<WorkoutExerciseSegment> = []
    @State private var targetAppliedBanner: TargetAppliedBanner? = nil
    
    @State private var coachPrompt: CoachPromptContext? = nil
    @State private var nextTargets: [UUID: PinnedTarget] = [:]
    
    @State private var prToast: PRToast? = nil
    @State private var prBadgesBySetId: [UUID: [CoachSuggestionService.PRAchievement]] = [:]
    @State private var confettiToken: UUID? = nil
    @State private var celebratedPRSetIDs: Set<UUID> = []
    
    @State private var prDetails: PRDetailsContext? = nil
    
    @State private var showReflectionSheet = false
    @State private var dismissAfterReflectionSheet = false
    
    private struct PRDetailsContext: Identifiable, Hashable {
        // Use setId as identity so it behaves nicely
        var id: UUID { setId }

        let setId: UUID
        let exerciseName: String
        let setNumber: Int
        let achievements: [CoachSuggestionService.PRAchievement]

        let weight: Double?
        let reps: Int?
        let unit: String
    }

    private struct PRToast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let subtitle: String
    }

    private let coachService = CoachSuggestionService()
    private let prService = PersonalRecordsService()

    private let continueNav = WorkoutContinueNavigator()

    private var isReadOnly: Bool { session.status != .inProgress }
    private var isInProgress: Bool { session.status == .inProgress }
    
    private var prefersSideBySideBottomOverlays: Bool {
        verticalSizeClass == .compact
    }

    private var bottomOverlayCardMaxWidth: CGFloat {
        prefersSideBySideBottomOverlays ? 320 : 440
    }

    private var bottomControlsMaxWidth: CGFloat {
        prefersSideBySideBottomOverlays ? 430 : 520
    }

    private var shouldShowCoachPrompt: Bool {
        showRestTimer && isInProgress && !session.isPaused && coachPrompt != nil
    }

    private var restTimerSnapshot: RestTimerSnapshot {
        restTimer.snapshot
    }

    private var shouldShowRestTimerCard: Bool {
        guard showRestTimer, isInProgress, !session.isPaused, restTimerSnapshot.shouldShow else {
            return false
        }

        if !prefs.restTimerShowOverdue, (restTimerSnapshot.isReady || restTimerSnapshot.isOverdue) {
            return false
        }

        return true
    }

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    headerSection
                    summarySectionIfReadOnly
                    segmentSummarySectionIfReadOnly
                    exercisesSection(proxy: proxy)
                }
                .accessibilityIdentifier("WorkoutSession.Screen")
                .navigationTitle(session.sourceRoutineNameSnapshot ?? String(localized: "session.title.fallback"))
                .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .safeAreaInset(edge: .bottom) { bottomInset(proxy: proxy) }
                .safeAreaInset(edge: .top) {
                    if let banner = targetAppliedBanner {
                        TargetAppliedBannerView(text: banner.text) {
                            withAnimation(.snappy) { targetAppliedBanner = nil }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .toolbar { toolbarContent }
                .confirmationDialog(
                    String(localized: "session.finish_workout.title"),
                    isPresented: $showFinishConfirm,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "session.finish_workout.action"), role: .destructive) { finish() }
                    Button(String(localized: "session.finish_workout.cancel"), role: .cancel) { }
                } message: {
                    Text(String(localized: "session.finish_workout.message"))
                }
                .confirmationDialog(
                    String(localized: "session.abandon_workout.title"),
                    isPresented: $showAbandonConfirm,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "session.abandon_workout.action"), role: .destructive) { abandon() }
                    Button(String(localized: "common.cancel"), role: .cancel) { }
                } message: {
                    Text(String(localized: "session.abandon_workout.message"))
                }
                .task(id: session.id) {
                    await applyGoalPrefillIfNeeded()
                    await reloadPinnedTargets()
                    await centerActionableSetOnOpen(proxy: proxy)
                }
                .safeAreaInset(edge: .top) {
                    if let prToast {
                        PRToastView(
                            title: prToast.title,
                            subtitle: prToast.subtitle,
                            onDismiss: { withAnimation(.snappy) { self.prToast = nil } }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            if let token = confettiToken {
                ConfettiBurstView(token: token)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showReflectionSheet, onDismiss: {
            if dismissAfterReflectionSheet { dismiss() }
            dismissAfterReflectionSheet = false
        }) {
            SessionReflectionSheet(session: session)
        }
        .sheet(item: $prDetails) { ctx in
            PRDetailsSheetView(ctx: ctx)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("WorkoutSession.Screen")
        .onAppear { syncRestTimerVisibility() }
        .onChange(of: restTimer.hasConfiguredTimer, initial: false) { _, hasConfiguredTimer in
            withAnimation { showRestTimer = hasConfiguredTimer ? showRestTimer || hasConfiguredTimer : false }
        }
        .onChange(of: restTimer.isRunning, initial: false) { _, isRunning in
            if isRunning {
                withAnimation { showRestTimer = true }
            } else if !restTimer.hasConfiguredTimer {
                withAnimation { showRestTimer = false }
            }
        }
        .onChange(of: restTimer.snapshot, initial: false) { _, snapshot in
            if !prefs.restTimerShowOverdue, (snapshot.isReady || snapshot.isOverdue) {
                withAnimation { showRestTimer = false }
            }
        }
        .onChange(of: restTimer.didFinishToken, initial: false) { _, token in
            guard token != nil, prefs.restTimerCueEnabled, prefs.hapticsEnabled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private var headerSection: some View {
        Section {
            HStack {
                LabeledContent(String(localized: "session.summary.started")) {
                    Text(AppFormatting.time(session.startedAt))
                }
                Spacer()
                LabeledContent(String(localized: "session.summary.status")) {
                    Text(statusLabel)
                        .foregroundStyle(session.status == .inProgress ? .secondary : .primary)
                }
            }

            HStack {
                LabeledContent(String(localized: "session.summary.elapsed")) {
                    Text(AppFormatting.duration(seconds: session.elapsedSeconds()))
                        .monospacedDigit()
                }
                Spacer()
                if session.isPaused {
                    Text(String(localized: "session.summary.paused")).font(.caption).foregroundStyle(.secondary)
                }
            }

            let completedSets = allSets.filter(\.completed).count
            let totalSets = allSets.count

            ProgressView(value: totalSets == 0 ? 0 : Double(completedSets) / Double(totalSets)) {
                Text(String(localized: "session.progress.title"))
            } currentValueLabel: {
                Text(String(format: String(localized: "session.progress.sets_value"), completedSets, max(totalSets, 1)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summarySectionIfReadOnly: some View {
        Group {
            if isReadOnly {
                Section(String(localized: "session.summary.title")) {
                    let completedSets = allSets.filter(\.completed).count
                    let totalSets = allSets.count

                    let volume = allSets.reduce(0.0) { acc, set in
                        guard set.completed else { return acc }
                        let reps = Double(set.reps ?? 0)
                        let w = set.weight ?? 0
                        return acc + (reps * w)
                    }

                    LabeledContent(String(localized: "session.summary.sets")) { Text("\(completedSets)/\(totalSets)") }

                    LabeledContent(String(localized: "session.summary.volume")) {
                        Text(AppFormatting.decimal(volume, maxFractionDigits: 0))
                            .foregroundStyle(.secondary)
                    }

                    if let endedAt = session.endedAt {
                        LabeledContent(String(localized: "session.summary.ended")) {
                            Text(AppFormatting.time(endedAt))
                        }
                    }
                }

                Section(String(localized: "session.reflection.title")) {
                    if let mood = session.reflectionMood {
                        LabeledContent(String(localized: "session.reflection.mood")) {
                            Text(mood.displayText)
                        }
                    }

                    let note = (session.reflectionNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button(hasReflection ? String(localized: "session.reflection.edit") : String(localized: "session.reflection.add")) {
                        dismissAfterReflectionSheet = false
                        showReflectionSheet = true
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var segmentSummarySectionIfReadOnly: some View {
        Group {
            if isReadOnly && sessionHasMultipleSegments {
                Section("Segments") {
                    ForEach(orderedVisibleSegmentKinds, id: \.self) { kind in
                        LabeledContent(segmentTitle(for: kind)) {
                            Text(segmentProgressText(for: kind) ?? "0/0 sets")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Data helpers

    private var allOrderedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var sortedExercises: [WorkoutSessionExercise] {
        allOrderedExercises.filter { !skippedSegmentKinds.contains($0.segment) }
    }

    private var allSets: [WorkoutSetLog] {
        sortedExercises.flatMap { sortedSets(for: $0) }
    }

    private func sortedSets(for ex: WorkoutSessionExercise) -> [WorkoutSetLog] {
        ex.setLogs.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var orderedVisibleSegmentKinds: [WorkoutExerciseSegment] {
        var seen: Set<WorkoutExerciseSegment> = []
        var ordered: [WorkoutExerciseSegment] = []

        for ex in sortedExercises {
            let kind = ex.segment
            if seen.insert(kind).inserted {
                ordered.append(kind)
            }
        }

        return ordered
    }

    private var sessionHasMultipleSegments: Bool {
        Set(allOrderedExercises.map(\.segment)).count > 1
    }

    private var currentSegmentKind: WorkoutExerciseSegment? {
        for ex in sortedExercises {
            if sortedSets(for: ex).contains(where: { !$0.completed }) {
                return ex.segment
            }
        }

        return sortedExercises.last?.segment
    }

    private func segmentTitle(for kind: WorkoutExerciseSegment) -> String {
        switch kind {
        case .warmUp: return "Warm-up"
        case .main: return "Workout"
        case .coolDown: return "Cool-down"
        }
    }

    private func segmentProgressText(for kind: WorkoutExerciseSegment) -> String? {
        let exercises = sortedExercises.filter { $0.segment == kind }
        guard !exercises.isEmpty else { return nil }

        let sets = exercises.flatMap { sortedSets(for: $0) }
        let total = sets.count
        let completed = sets.filter(\.completed).count
        return "\(completed)/\(max(total, 1)) sets"
    }

    private func isStartOfSegment(at index: Int) -> Bool {
        guard index < sortedExercises.count else { return false }
        guard index > 0 else { return true }
        return sortedExercises[index - 1].segment != sortedExercises[index].segment
    }

    private func canSkipSegment(_ kind: WorkoutExerciseSegment) -> Bool {
        isInProgress && !session.isPaused && kind == currentSegmentKind && (kind == .warmUp || kind == .coolDown)
    }

    private func firstIncompleteVisibleTarget() -> (exercise: WorkoutSessionExercise, set: WorkoutSetLog)? {
        for ex in sortedExercises {
            if let set = sortedSets(for: ex).first(where: { !$0.completed }) {
                return (ex, set)
            }
        }
        return nil
    }

    private func skipCurrentSegment() {
        guard let kind = currentSegmentKind, canSkipSegment(kind) else { return }

        withAnimation(.snappy) {
            skippedSegmentKinds.insert(kind)
            coachPrompt = nil
            showRestTimer = false
        }
        restTimer.resolveForNextAction()

        if let target = firstIncompleteVisibleTarget() {
            markActive(exerciseID: target.exercise.id, setID: target.set.id)
        } else {
            activeExerciseID = nil
            activeSetID = nil
            if kind == .coolDown {
                finish()
            }
        }
    }

    private var statusLabel: String {
        switch session.status {
        case .inProgress: return String(localized: "session.status.in_progress")
        case .completed: return String(localized: "session.status.completed")
        case .abandoned: return String(localized: "session.status.abandoned")
        }
    }
    
    private var hasReflection: Bool {
        if session.reflectionMood != nil { return true }
        let note = (session.reflectionNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !note.isEmpty
    }

    // MARK: Logging actions

    private func continueLogging(proxy: ScrollViewProxy) {
        if session.isPaused {
            session.resume()
            withAnimation { showRestTimer = false }
            saveOrAssert("resume")
        }

        guard let target = nextActionableTarget() else { return }

        restTimer.resolveForNextAction()
        activeExerciseID = target.exerciseID
        activeSetID = target.setID

        scrollToExercise(target.setID, proxy: proxy)
    }
    
    private func nextActionableTarget() -> ActionableSetTarget? {
        let exercises = sortedExercises
        guard !exercises.isEmpty else { return nil }

        guard let targetSetID = continueNav.nextTargetSetID(
            exercises: exercises,
            activeExerciseID: activeExerciseID,
            activeSetID: activeSetID
        ) else { return nil }

        guard let owningExercise = exercises.first(where: { ex in
            ex.setLogs.contains(where: { $0.id == targetSetID })
        }) else {
            return nil
        }

        return ActionableSetTarget(
            exerciseID: owningExercise.id,
            setID: targetSetID
        )
    }

    private func centerActionableSetOnOpen(proxy: ScrollViewProxy) async {
        guard isInProgress else { return }
        guard let target = nextActionableTarget() else { return }

        activeExerciseID = target.exerciseID
        activeSetID = target.setID

        // Let List + bottom safe-area content settle before the initial scroll.
        try? await Task.sleep(nanoseconds: 150_000_000)
        scrollToExercise(target.setID, proxy: proxy)
    }

    private func handleSetCompleted(
        ex: WorkoutSessionExercise,
        set: WorkoutSetLog,
        suggestedRest: Int?
    ) {
        guard isInProgress, !session.isPaused else { return }

        // This is critical: Continue navigation uses the active exercise/set cursor.
        // Without updating it here, Continue can look like it does nothing because it
        // falls back to a generic first-incomplete lookup.
        markActive(exerciseID: ex.id, setID: set.id)

        let prompt = coachService.makePrompt(
            completedWeight: set.weight,
            completedReps: set.reps,
            weightUnitRaw: set.weightUnit.rawValue,
            rpe: set.rpe,
            plannedRestSeconds: set.targetRestSeconds,
            defaultRestSeconds: suggestedRest ?? 90
        )

        coachPrompt = CoachPromptContext(
            sessionExerciseModelId: ex.id,
            exerciseId: ex.exerciseId,
            completedSetId: set.id,
            completedSetOrder: set.order,
            prompt: prompt
        )

        // Start rest timer using coach suggestion
        restTimer.configure(
            seconds: max(1, prompt.suggestedRestSeconds),
            startImmediately: prefs.autoStartRest,
            playStartCue: prefs.restTimerCueEnabled
        )
        withAnimation { showRestTimer = true }
    }

    // MARK: View builders

    @ViewBuilder
    private func exercisesSection(proxy: ScrollViewProxy) -> some View {
        if sortedExercises.isEmpty {
            emptyExercisesSection
        } else {
            ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, ex in
                if isStartOfSegment(at: index) {
                    SessionSegmentHeaderView(
                        kind: ex.segment,
                        progressText: segmentProgressText(for: ex.segment),
                        isCurrent: ex.segment == currentSegmentKind,
                        showsSkipAction: canSkipSegment(ex.segment),
                        onSkip: canSkipSegment(ex.segment) ? { skipCurrentSegment() } : nil
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                exerciseSection(ex, proxy: proxy)
            }
        }
    }

    private var emptyExercisesSection: some View {
        Section {
            ContentUnavailableView(
                String(localized: "session.empty.title"),
                systemImage: "dumbbell",
                description: Text(String(localized: "session.empty.message"))
            )
        }
    }

    private func exerciseSection(_ ex: WorkoutSessionExercise, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            exerciseCardHeader(ex)

            VStack(alignment: .leading, spacing: 10) {
                setsList(for: ex, proxy: proxy)
            }
        }
        .id(ex.id)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            activeExerciseID == ex.id
            ? "WorkoutSession.ActionableExerciseCard"
            : "WorkoutSession.ExerciseCard.\(ex.id.uuidString)"
        )
        .padding(14)
        .background(exerciseCardBackground)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func exerciseCardHeader(_ ex: WorkoutSessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ex.exerciseNameSnapshot)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isInProgress, let t = nextTargets[ex.exerciseId] {
                HStack(spacing: 8) {
                    Text(String(format: String(localized: "session.next_target"), t.text))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Button(String(localized: "common.apply")) {
                        applyPinnedTarget(for: ex)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var exerciseCardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.secondary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func setsList(for ex: WorkoutSessionExercise, proxy: ScrollViewProxy) -> some View {
        let sets = sortedSets(for: ex)

        VStack(spacing: 10) {
            ForEach(sets, id: \.id) { set in
                let state = setRowVisualState(for: set)

                setRow(ex: ex, set: set, proxy: proxy)
                    .id(set.id)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(setRowChrome(state: state))
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(setRowAccessibilityIdentifier(for: set, state: state))
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            markActive(exerciseID: ex.id, setID: set.id)
                        }
                    )
            }
        }
    }

    // MARK: - Row styling

    private enum SetRowVisualState: Equatable {
        case pending
        case current
        case done
        case behind
    }

    private func setRowVisualState(for set: WorkoutSetLog) -> SetRowVisualState {
        if activeSetID == set.id { return .current }
        if set.completed { return .done }
        if isBehind(set) { return .behind }
        return .pending
    }
    
    private func setRowAccessibilityIdentifier(for set: WorkoutSetLog, state: SetRowVisualState) -> String {
        if state == .current {
            return "WorkoutSession.ActionableSetRow"
        }
        return "WorkoutSession.SetRow.\(set.id.uuidString)"
    }

    private var behindSetIDs: Set<UUID> {
        guard isInProgress, let activeSetID else { return [] }

        let ordered: [WorkoutSetLog] = sortedExercises.flatMap { ex in
            sortedSets(for: ex)
        }

        guard let activeIndex = ordered.firstIndex(where: { $0.id == activeSetID }) else { return [] }

        return Set(
            ordered.prefix(activeIndex)
                .filter { !$0.completed }
                .map(\.id)
        )
    }

    private func isBehind(_ set: WorkoutSetLog) -> Bool {
        behindSetIDs.contains(set.id)
    }

    private func setRowChrome(state: SetRowVisualState) -> some View {
        let bg: Color
        let border: Color
        let bar: Color?

        switch state {
        case .pending:
            bg = Color.secondary.opacity(0.03)
            border = Color.secondary.opacity(0.10)
            bar = nil
        case .current:
            bg = Color.accentColor.opacity(0.12)
            border = Color.accentColor.opacity(0.28)
            bar = Color.accentColor
        case .done:
            bg = Color.green.opacity(0.12)
            border = Color.green.opacity(0.22)
            bar = nil
        case .behind:
            bg = Color.orange.opacity(0.06)
            border = Color.orange.opacity(0.18)
            bar = nil
        }

        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                if let bar {
                    Capsule()
                        .fill(bar)
                        .frame(width: 4)
                        .padding(.leading, 10)
                        .padding(.vertical, 10)
                }
            }
    }



    @ViewBuilder
    private func bottomInset(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 10) {
            if shouldShowCoachPrompt || shouldShowRestTimerCard {
                if prefersSideBySideBottomOverlays && shouldShowCoachPrompt && shouldShowRestTimerCard {
                    HStack(alignment: .bottom, spacing: 10) {
                        if let ctx = coachPrompt {
                            coachPromptOverlay(ctx, proxy: proxy, paired: true)
                                .zIndex(3)
                        }

                        restTimerOverlay(paired: true)
                            .zIndex(3)
                    }
                } else {
                    VStack(spacing: 10) {
                        if let ctx = coachPrompt, shouldShowCoachPrompt {
                            coachPromptOverlay(ctx, proxy: proxy, paired: false)
                                .zIndex(3)
                        }

                        if shouldShowRestTimerCard {
                            restTimerOverlay(paired: false)
                                .zIndex(3)
                        }
                    }
                }
            }

            if let toast = logging.undoToast, isInProgress {
                UndoToastView(
                    message: toast.message,
                    onUndo: { logging.undoLast(context: modelContext) },
                    onDismiss: { logging.clearUndoToast() }
                )
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }

            if isInProgress {
                bottomActionBar(proxy: proxy)
                    .zIndex(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private func coachPromptOverlay(
        _ ctx: CoachPromptContext,
        proxy: ScrollViewProxy,
        paired: Bool
    ) -> some View {
        CoachPromptCardView(
            title: ctx.prompt.title,
            message: ctx.prompt.message,
            suggestedRestSeconds: ctx.prompt.suggestedRestSeconds,
            weightActionTitle: ctx.prompt.weightLabel.map { String(format: String(localized: "session.coach.next_set"), $0) },
            repsActionTitle: ctx.prompt.repsLabel.map { String(format: String(localized: "session.coach.next_set"), $0) },
            onApplyWeight: ctx.prompt.weightDelta == nil ? nil : { applyCoachWeight(ctx, proxy: proxy) },
            onApplyReps: ctx.prompt.repsDelta == nil ? nil : { applyCoachReps(ctx, proxy: proxy) },
            onStartRest: {
                restTimer.configure(
                    seconds: max(1, ctx.prompt.suggestedRestSeconds),
                    startImmediately: prefs.autoStartRest,
                    playStartCue: prefs.restTimerCueEnabled
                )
                withAnimation { showRestTimer = true }
            },
            onDismiss: { withAnimation { coachPrompt = nil } }
        )
        .frame(maxWidth: bottomOverlayCardMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: paired ? .leading : .center)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func restTimerOverlay(paired: Bool) -> some View {
        RestTimerView {
            withAnimation { showRestTimer = false }
        }
        .frame(maxWidth: bottomOverlayCardMaxWidth)
        .frame(maxWidth: .infinity, alignment: paired ? .trailing : .center)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func bottomActionBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            Button {
                continueLogging(proxy: proxy)
            } label: {
                Label(
                    session.isPaused ? String(localized: "session.resume") : String(localized: "session.continue"),
                    systemImage: session.isPaused ? "play.fill" : "arrow.down.to.line"
                )
            }
            .accessibilityIdentifier("WorkoutSession.ContinueButton")
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            if !session.isPaused {
                Button {
                    session.pause()
                    restTimer.resolveForNextAction()
                    withAnimation { showRestTimer = false }
                    saveOrAssert("pause")
                } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel(AccessibilityLabels.Buttons.pauseWorkout)
            }

            Button {
                showFinishConfirm = true
            } label: {
                Label(String(localized: "session.finish.button"), systemImage: "checkmark.circle")
            }
            .accessibilityIdentifier("WorkoutSession.FinishButton")
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .frame(maxWidth: bottomControlsMaxWidth)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isInProgress {
                Button {
                    if showRestTimer {
                        withAnimation { showRestTimer = false }
                    } else {
                        restTimer.configure(
                            seconds: max(1, prefs.defaultRestSeconds),
                            startImmediately: prefs.autoStartRest,
                            playStartCue: prefs.restTimerCueEnabled
                        )
                        withAnimation { showRestTimer = true }
                    }
                } label: {
                    Label(
                        showRestTimer ? String(localized: "session.rest.hide") : String(localized: "session.rest.title"),
                        systemImage: showRestTimer ? "timer.circle.fill" : "timer.circle"
                    )
                }
                .accessibilityIdentifier("WorkoutSession.RestTimerButton")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if isInProgress {
                Menu {
                    Button(String(localized: "session.abandon_workout.action"), systemImage: "xmark.circle", role: .destructive) {
                        showAbandonConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            } else {
                Button(String(localized: "common.close")) { dismiss() }
                    .fontWeight(.semibold)
            }
        }
    }

    private func syncRestTimerVisibility() {
        if restTimer.isRunning || restTimer.hasConfiguredTimer {
            if !prefs.restTimerShowOverdue, (restTimerSnapshot.isReady || restTimerSnapshot.isOverdue) {
                showRestTimer = false
            } else {
                showRestTimer = true
            }
        } else {
            showRestTimer = false
        }
    }


    // MARK: Finish/abandon

    private func finish() {
        if session.isPaused { session.resume() }
        restTimer.resolveForNextAction()
        session.endedAt = Date()
        session.status = .completed
        saveOrAssert("finish")

        // Optional, post-session, never blocks logging flow:
        // we only prompt if the user hasn't added a reflection yet.
        if !hasReflection {
            dismissAfterReflectionSheet = true
            showReflectionSheet = true
        } else {
            dismiss()
        }
    }

    private func abandon() {
        if session.isPaused { session.resume() }
        restTimer.resolveForNextAction()
        session.endedAt = Date()
        session.status = .abandoned
        saveOrAssert("abandon")
        dismiss()
    }

    // MARK: Persistence + formatting

    private func saveOrAssert(_ label: String) {
        do { try modelContext.save() }
        catch { assertionFailure("Failed to save (\(label)): \(error)") }
    }

    
    private func markActive(exerciseID: UUID, setID: UUID?) {
        activeExerciseID = exerciseID
        activeSetID = setID
    }
    
    private struct ActionableSetTarget {
        let exerciseID: UUID
        let setID: UUID
    }
    
    @ViewBuilder
    private func setRow(ex: WorkoutSessionExercise, set: WorkoutSetLog, proxy: ScrollViewProxy) -> some View {
        if WorkoutSetRowRouting.shouldUseTimedRow(for: ex, set: set) {
            TimedSetEditorRow(
                set: set,
                setNumber: displaySetNumber(for: set, in: ex),
                isReadOnly: isReadOnly,
                showsDistance: (ex.trackingStyle.showsDistance || set.targetDistance != nil || set.actualDistance != nil),
                onPersist: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    saveOrAssert("set edit")
                },
                onToggleComplete: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    logging.toggleCompleted(set, context: modelContext)
                    saveOrAssert("toggle complete")
                },
                onCopySet: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    dismissKeyboard()

                    if !isReadOnly, let newSet = logging.copySet(set, in: ex, context: modelContext) {
                        applyTimedTemplate(from: set, to: newSet, prefillActuals: true)
                        markActive(exerciseID: ex.id, setID: newSet.id)
                        saveOrAssert("copy set")
                        scrollToExercise(newSet.id, proxy: proxy)
                    }
                },
                onAddSet: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    if !isReadOnly, let newSet = logging.addSet(to: ex, after: set, template: set, context: modelContext) {
                        // "Add" should keep targets but not clone actual duration/distance.
                        applyTimedTemplate(from: set, to: newSet, prefillActuals: false)
                        newSet.actualDurationSeconds = nil
                        newSet.actualDistance = nil
                        newSet.completed = false
                        newSet.completedAt = nil

                        markActive(exerciseID: ex.id, setID: newSet.id)
                        saveOrAssert("add set")
                        scrollToExercise(newSet.id, proxy: proxy)
                    }
                },
                onDeleteSet: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    if !isReadOnly {
                        logging.deleteSet(set, from: ex, context: modelContext)
                        saveOrAssert("delete set")
                        if activeSetID == set.id { activeSetID = nil }
                    }
                }
            )
        } else {
            WorkoutSetEditorRow(
                set: set,
                setNumber: displaySetNumber(for: set, in: ex),
                isReadOnly: isReadOnly,
                onCompleted: { suggestedRest in
                    handleSetCompleted(ex: ex, set: set, suggestedRest: suggestedRest)
                },
                onPersist: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    saveOrAssert("set edit")
                },
                onToggleComplete: {
                    markActive(exerciseID: ex.id, setID: set.id)

                    let wasCompleted = set.completed
                    logging.toggleCompleted(set, context: modelContext)

                    // If user un-completes, clear PR markers so re-completing can celebrate again.
                    if wasCompleted && !set.completed {
                        prBadgesBySetId[set.id] = nil
                        celebratedPRSetIDs.remove(set.id)
                        return
                    }

                    // Only trigger celebration on the transition to completed.
                    if !wasCompleted && set.completed {
                        Task { await celebratePRIfNeeded(ex: ex, set: set) }
                    }
                },
                onCopySet: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    dismissKeyboard()

                    if !isReadOnly, let newSet = logging.copySet(set, in: ex, context: modelContext) {
                        markActive(exerciseID: ex.id, setID: newSet.id)
                        saveOrAssert("copy set")
                        scrollToExercise(newSet.id, proxy: proxy)
                    }
                },
                onAddSet: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    if !isReadOnly, let newSet = logging.addSet(to: ex, after: set, template: set, context: modelContext) {
                        // "Add" keeps targets (plan) but clears actuals; otherwise it's indistinguishable from "Copy".
                        newSet.reps = nil
                        newSet.weight = nil
                        newSet.completed = false
                        newSet.completedAt = nil

                        markActive(exerciseID: ex.id, setID: newSet.id)
                        saveOrAssert("add set")
                        scrollToExercise(newSet.id, proxy: proxy)
                    }
                },
                onDeleteSet: {
                    markActive(exerciseID: ex.id, setID: set.id)
                    if !isReadOnly {
                        logging.deleteSet(set, from: ex, context: modelContext)
                        saveOrAssert("delete set")
                        if activeSetID == set.id { activeSetID = nil }
                    }
                },
                onBumpReps: { delta in
                    markActive(exerciseID: ex.id, setID: set.id)
                    if !isReadOnly { logging.bumpReps(set, delta: delta, context: modelContext) }
                },
                onBumpWeight: { delta in
                    markActive(exerciseID: ex.id, setID: set.id)
                    if !isReadOnly { logging.bumpWeight(set, delta: delta, context: modelContext) }
                },
                weightStep: 2.5
            )
            .overlay(alignment: .topTrailing) {
                if let ach = prBadgesBySetId[set.id], !ach.isEmpty {
                    Button {
                        prDetails = PRDetailsContext(
                            setId: set.id,
                            exerciseName: ex.exerciseNameSnapshot,
                            setNumber: displaySetNumber(for: set, in: ex),
                            achievements: ach,
                            weight: set.weight,
                            reps: set.reps,
                            unit: set.weightUnit.rawValue
                        )
                    } label: {
                        Text(String(localized: "session.pr.badge"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.yellow.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .accessibilityLabel(AccessibilityLabels.Buttons.showPRDetails)
                }
            }
        }
    }

    /// Timed / distance sets are detected by the presence of those target/actual fields.
    private func isTimedSet(_ set: WorkoutSetLog) -> Bool {
        set.targetDurationSeconds != nil ||
        set.actualDurationSeconds != nil ||
        set.targetDistance != nil ||
        set.actualDistance != nil
    }

    /// Keep cardio/mobility sets “timed” even when created via generic add/copy helpers that
    /// might only clone reps/weight fields.
    private func applyTimedTemplate(from template: WorkoutSetLog?, to set: WorkoutSetLog, prefillActuals: Bool) {
        guard let template else { return }
        guard isTimedSet(template) else { return }

        set.targetDurationSeconds = template.targetDurationSeconds
        set.targetDistance = template.targetDistance

        if prefillActuals {
            set.actualDurationSeconds = template.actualDurationSeconds ?? template.targetDurationSeconds
            set.actualDistance = template.actualDistance ?? template.targetDistance
        } else {
            // Keep whatever actuals it already had.
        }
    }

    @MainActor
    private func applyGoalPrefillIfNeeded() async {
        guard session.status == .inProgress else { return }
        guard let exId = goalPrefill.pendingExerciseId else { return }
        guard let target = goalPrefill.consumeIfMatches(exerciseId: exId) else { return }

        guard let ex = session.exercises.first(where: { $0.exerciseId == exId }) else { return }
        guard let set = ex.setLogs
            .sorted(by: { $0.order < $1.order })
            .first(where: { !$0.completed }) else { return }

        var changed = false

        // Only prefill if user hasn't already typed something
        if let w = target.weight, (set.weight ?? 0) == 0 {
            set.weight = w
            changed = true
        }
        if let r = target.reps, (set.reps ?? 0) == 0 {
            set.reps = r
            changed = true
        }

        if changed { try? modelContext.save() }

        // ✅ Banner feedback (always, so user knows what happened)
        let msg = changed
            ? bannerMessageApplied(target: target, setNumber: displaySetNumber(for: set, in: ex), unit: set.weightUnit.rawValue)
            : String(localized: "session.target_prefill.no_change")

        showTargetAppliedBanner(msg)
    }
    
    private struct TargetAppliedBanner: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    @MainActor
    private func showTargetAppliedBanner(_ text: String) {
        let banner = TargetAppliedBanner(text: text)
        withAnimation(.snappy) { targetAppliedBanner = banner }

        Task { [id = banner.id] in
            try? await Task.sleep(nanoseconds: 2_200_000_000) // ~2.2s
            await MainActor.run {
                guard targetAppliedBanner?.id == id else { return }
                withAnimation(.snappy) { targetAppliedBanner = nil }
            }
        }
    }

    private func bannerMessageApplied(target: GoalPrefillStore.Prefill, setNumber: Int, unit: String) -> String {
        var parts: [String] = []
        if let w = target.weight { parts.append("\(formatWeight(w)) \(unit)") }
        if let r = target.reps { parts.append(String(format: String(localized: "session.pr.reps"), r)) }

        if parts.isEmpty {
            return String(format: String(localized: "session.target_prefill.applied_set"), setNumber)
        } else {
            return String(format: String(localized: "session.target_prefill.applied_set_details"), setNumber, parts.joined(separator: " • "))
        }
    }

    private func formatWeight(_ w: Double) -> String {
        if w.rounded() == w { return AppFormatting.decimal(w, maxFractionDigits: 0) }
        return AppFormatting.decimal(w, maxFractionDigits: 1)
    }

    private struct TargetAppliedBannerView: View {
        let text: String
        let onDismiss: () -> Void

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.secondary.opacity(0.15), lineWidth: 1)
            )
            .onTapGesture { onDismiss() }
        }
    }

    @MainActor
    private func fetchFirstIncompleteSetLog(sessionExerciseId: UUID) -> WorkoutSetLog? {
        let sid: UUID? = sessionExerciseId

        var fd = FetchDescriptor<WorkoutSetLog>(
            predicate: #Predicate<WorkoutSetLog> { s in
                s.completed == false &&
                s.sessionExercise?.id == sid
            },
            sortBy: [SortDescriptor(\WorkoutSetLog.order, order: .forward)]
        )
        fd.fetchLimit = 1
        return try? modelContext.fetch(fd).first
    }
    
    private func dismissKeyboard() {
    #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    #endif
    }
    
    private func scrollToExercise(_ id: UUID, proxy: ScrollViewProxy) {
        dismissKeyboard()

        Task { @MainActor in
            withAnimation(.snappy) {
                proxy.scrollTo(id, anchor: .center)
            }

            // Second pass helps after List/layout/bottom-inset settling.
            try? await Task.sleep(nanoseconds: 120_000_000)

            withAnimation(.snappy) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
    
    private struct PinnedTarget: Hashable {
        let text: String
        let weight: Double?
        let reps: Int?
    }

    private struct CoachPromptContext: Identifiable, Hashable {
        let id = UUID()
        let sessionExerciseModelId: UUID   // WorkoutSessionExercise.id
        let exerciseId: UUID              // WorkoutSessionExercise.exerciseId
        let completedSetId: UUID
        let completedSetOrder: Int
        let prompt: CoachSuggestionService.Prompt
    }
    
    @MainActor
    private func reloadPinnedTargets() async {
        var out: [UUID: PinnedTarget] = [:]

        for ex in sortedExercises {
            do {
                let rec = try prService.records(for: ex.exerciseId, context: modelContext)
                if let t = try prService.nextTarget(for: ex.exerciseId, records: rec, context: modelContext) {
                    out[ex.exerciseId] = PinnedTarget(text: t.text, weight: t.targetWeight, reps: t.targetReps)
                }
            } catch {
                // ignore; keep UX smooth
            }
        }

        nextTargets = out
    }
    @MainActor
    private func applyPinnedTarget(for ex: WorkoutSessionExercise) {
        guard let t = nextTargets[ex.exerciseId] else { return }

        // Apply into the first incomplete set (by order); create one if none exist.
        let sets = sortedSets(for: ex)
        let targetSet: WorkoutSetLog

        if let s = sets.first(where: { !$0.completed }) {
            targetSet = s
        } else {
            // No available set: create a new one using your logging service
            if let newSet = logging.addSet(to: ex, template: sets.last, context: modelContext) {
                targetSet = newSet
            } else {
                return
            }
        }

        // Don't overwrite user-entered values
        if let w = t.weight, (targetSet.weight ?? 0) == 0 { targetSet.weight = w }
        if let r = t.reps, (targetSet.reps ?? 0) == 0 { targetSet.reps = r }

        saveOrAssert("apply next target")
    }
    
    @MainActor
    private func applyCoachWeight(_ ctx: CoachPromptContext, proxy: ScrollViewProxy) {
        guard let delta = ctx.prompt.weightDelta else { return }
        guard let ex = session.exercises.first(where: { $0.id == ctx.sessionExerciseModelId }) else { return }
        guard let completed = sortedSets(for: ex).first(where: { $0.id == ctx.completedSetId }) else { return }

        let next = nextEditableSet(after: completed, in: ex)
        guard let next else { return }

        let base = (next.weight ?? 0) > 0 ? (next.weight ?? 0) : (completed.weight ?? 0)
        next.weight = base + delta

        saveOrAssert("coach apply weight")
        coachPrompt = nil
        scrollToExercise(next.id, proxy: proxy)
    }

    @MainActor
    private func applyCoachReps(_ ctx: CoachPromptContext, proxy: ScrollViewProxy) {
        guard let delta = ctx.prompt.repsDelta else { return }
        guard let ex = session.exercises.first(where: { $0.id == ctx.sessionExerciseModelId }) else { return }
        guard let completed = sortedSets(for: ex).first(where: { $0.id == ctx.completedSetId }) else { return }

        let next = nextEditableSet(after: completed, in: ex)
        guard let next else { return }

        let base = (next.reps ?? 0) > 0 ? (next.reps ?? 0) : (completed.reps ?? 0)
        next.reps = base + delta

        saveOrAssert("coach apply reps")
        coachPrompt = nil
        scrollToExercise(next.id, proxy: proxy)
    }

    @MainActor
    private func nextEditableSet(after completed: WorkoutSetLog, in ex: WorkoutSessionExercise) -> WorkoutSetLog? {
        let sets = sortedSets(for: ex)

        if let existing = sets.first(where: { !$0.completed && $0.order > completed.order }) {
            return existing
        }

        // No future set exists → create one after the completed set
        if let newSet = logging.addSet(to: ex, after: completed, template: completed, context: modelContext) {
            return newSet
        }

        return nil
    }
    
    @MainActor
    private func celebratePRIfNeeded(ex: WorkoutSessionExercise, set: WorkoutSetLog) async {
        // Only celebrate completed sets with a timestamp
        guard !celebratedPRSetIDs.contains(set.id) else { return }
        guard set.completed, set.completedAt != nil else { return }

        // Fetch *previous history* for this exercise (excluding this set)
        let previous = fetchCompletedSetsForExercise(exerciseId: ex.exerciseId)
            .filter { $0.id != set.id }

        let prev = previous.map {
            CoachSuggestionService.CompletedSet(
                weight: $0.weight,
                reps: $0.reps,
                weightUnitRaw: $0.weightUnit.rawValue,
                rpe: $0.rpe
            )
        }

        let cur = CoachSuggestionService.CompletedSet(
            weight: set.weight,
            reps: set.reps,
            weightUnitRaw: set.weightUnit.rawValue,
            rpe: set.rpe
        )

        let achievements = coachService.prAchievements(completed: cur, previous: prev)
        guard !achievements.isEmpty else { return }
        celebratedPRSetIDs.insert(set.id)
        Haptics.success()

        // 1) Mark badge for this set row
        prBadgesBySetId[set.id] = achievements

        // 2) Toast message
        let headline = String(localized: "session.pr.toast_title")
        let subtitle = achievements
            .map { "\($0.kind.rawValue): \($0.valueText)" }
            .joined(separator: " • ")

        withAnimation(.snappy) {
            prToast = PRToast(title: headline, subtitle: subtitle)
            confettiToken = UUID()
        }

        // auto-dismiss toast + confetti
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                withAnimation(.snappy) {
                    prToast = nil
                    confettiToken = nil
                }
            }
        }
    }

    private struct PRDetailsSheetView: View {
        let ctx: PRDetailsContext
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ctx.exerciseName)
                                .font(.headline)

                            HStack(spacing: 10) {
                                Text(String(format: String(localized: "session.pr.set_number"), ctx.setNumber))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                if let w = ctx.weight {
                                    Text("\(AppFormatting.decimal(w, maxFractionDigits: 1)) \(ctx.unit)")
                                        .font(.subheadline.weight(.semibold))
                                }
                                if let r = ctx.reps {
                                    Text(String(format: String(localized: "session.pr.reps"), r))
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section(String(localized: "session.pr.section_title")) {
                        ForEach(Array(ctx.achievements.enumerated()), id: \.offset) { _, a in
                            HStack(spacing: 10) {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.kind.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                    Text(a.valueText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .navigationTitle(String(localized: "session.pr.sheet_title"))
                .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "common.done")) { dismiss() }
                    }
                }
            }
        }

    }

    @MainActor
    private func fetchCompletedSetsForExercise(exerciseId: UUID) -> [WorkoutSetLog] {
        let exId: UUID? = exerciseId

        do {
            let fd = FetchDescriptor<WorkoutSetLog>(
                predicate: #Predicate<WorkoutSetLog> { s in
                    s.completed == true &&
                    s.sessionExercise?.exerciseId == exId
                },
                sortBy: [SortDescriptor(\WorkoutSetLog.completedAt, order: .forward)]
            )
            return try modelContext.fetch(fd)
        } catch {
            return []
        }
    }
    

    private struct TimedSetEditorRow: View {
        @Bindable var set: WorkoutSetLog
        @AppStorage(UnitPreferences.Keys.distanceUnitRaw)
        private var preferredDistanceUnitRaw: String = DistanceUnit.km.rawValue
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass

        var setNumber: Int
        var isReadOnly: Bool
        var showsDistance: Bool

        var onPersist: () -> Void
        var onToggleComplete: () -> Void
        var onCopySet: () -> Void
        var onAddSet: () -> Void
        var onDeleteSet: () -> Void

        private var preferredDistanceUnit: DistanceUnit {
            DistanceUnit(rawValue: preferredDistanceUnitRaw) ?? .km
        }

        private var isCompact: Bool { horizontalSizeClass == .compact }
        private var stacksMetricsVertically: Bool { isCompact && showsDistance }
        private var metricSpacing: CGFloat { isCompact ? 10 : 16 }
        private var durationFieldWidth: CGFloat { isCompact ? 50 : 54 }
        private var distanceFieldWidth: CGFloat { isCompact ? 58 : 64 }

        var body: some View {
            HStack(alignment: .top, spacing: isCompact ? 8 : 14) {
                Text("\(setNumber)")
                    .font(.headline)
                    .frame(width: 28, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .layoutPriority(2)

                VStack(alignment: .leading, spacing: 10) {
                    metricsBlock

                    SetRowActionsBar(
                        isReadOnly: isReadOnly,
                        onAction: { action in
                            switch action {
                            case .copy:
                                onCopySet()
                            case .add:
                                onAddSet()
                            case .delete:
                                onDeleteSet()
                            }
                        },
                        idPrefix: "WorkoutSetEditorRow.\(set.id.uuidString).Actions"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Button {
                    if !isReadOnly { onToggleComplete() }
                } label: {
                    Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(set.completed ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 36, alignment: .trailing)
                .layoutPriority(2)
                .accessibilityLabel(set.completed ? String(localized: "a11y.button.mark_incomplete") : String(localized: "a11y.button.mark_complete"))
                .accessibilityIdentifier("WorkoutSetEditorRow.\(set.id.uuidString).DoneToggle")
                .disabled(isReadOnly)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }

        @ViewBuilder
        private var metricsBlock: some View {
            if stacksMetricsVertically {
                VStack(alignment: .leading, spacing: 10) {
                    durationField

                    if showsDistance {
                        distanceField
                    }
                }
            } else {
                HStack(alignment: .top, spacing: metricSpacing) {
                    durationField

                    if showsDistance {
                        distanceField
                    }
                }
            }
        }

        private var durationField: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "session.time.minutes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: isCompact ? 6 : 8) {
                    stepButton(system: "minus.circle") { bumpDurationMinutes(-1) }

                    TextField("—", text: durationMinutesBinding)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(width: durationFieldWidth)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isReadOnly)

                    stepButton(system: "plus.circle") { bumpDurationMinutes(+1) }
                }
            }
            .layoutPriority(1)
        }

        private var distanceField: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(isCompact ? "Dist (\(preferredDistanceUnit.symbol))" : "Distance (\(preferredDistanceUnit.symbol))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: isCompact ? 6 : 8) {
                    stepButton(system: "minus.circle") { bumpDistance(-preferredDistanceUnit.stepSize) }

                    TextField("—", text: distanceBinding)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .frame(width: distanceFieldWidth)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isReadOnly)

                    stepButton(system: "plus.circle") { bumpDistance(+preferredDistanceUnit.stepSize) }
                }
            }
            .layoutPriority(1)
        }

        private func stepButton(system: String, action: @escaping () -> Void) -> some View {
            Button {
                if !isReadOnly {
                    action()
                    onPersist()
                }
            } label: {
                Image(systemName: system)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isReadOnly)
        }

        private var durationMinutesBinding: Binding<String> {
            Binding(
                get: {
                    let seconds = set.actualDurationSeconds ?? set.targetDurationSeconds
                    guard let seconds else { return "" }
                    let minutes = max(0, Int(round(Double(seconds) / 60.0)))
                    return minutes == 0 ? "" : String(minutes)
                },
                set: { newValue in
                    guard !isReadOnly else { return }
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let m = Int(trimmed), m >= 0 else {
                        set.actualDurationSeconds = nil
                        onPersist()
                        return
                    }
                    set.actualDurationSeconds = m * 60
                    onPersist()
                }
            )
        }

        private var distanceBinding: Binding<String> {
            Binding(
                get: {
                    guard let v = set.editableDistance(in: preferredDistanceUnit) else { return "" }
                    let rounded = (v * 10).rounded() / 10
                    return rounded == 0 ? "" : String(format: "%.1f", rounded)
                },
                set: { newValue in
                    guard !isReadOnly else { return }
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                    guard let d = Double(normalized), d >= 0 else {
                        set.setActualDistance(nil, preferredUnit: preferredDistanceUnit)
                        onPersist()
                        return
                    }
                    set.setActualDistance(d == 0 ? nil : d, preferredUnit: preferredDistanceUnit)
                    onPersist()
                }
            )
        }

        private func bumpDurationMinutes(_ delta: Int) {
            let currentSeconds = set.actualDurationSeconds ?? set.targetDurationSeconds ?? 0
            let currentMinutes = max(0, Int(round(Double(currentSeconds) / 60.0)))
            let next = max(0, currentMinutes + delta)
            set.actualDurationSeconds = next * 60
        }

        private func bumpDistance(_ delta: Double) {
            let current = set.editableDistance(in: preferredDistanceUnit) ?? 0
            let next = max(0, current + delta)
            set.setActualDistance(next == 0 ? nil : next, preferredUnit: preferredDistanceUnit)
        }
    }
    
    @MainActor
    private static func playRestFinishedHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    private enum Haptics {
        static func success() {
    #if canImport(UIKit)
        Task { @MainActor in
            WorkoutSessionScreen.playRestFinishedHaptic()
        }
    #endif
        }
    }
}
