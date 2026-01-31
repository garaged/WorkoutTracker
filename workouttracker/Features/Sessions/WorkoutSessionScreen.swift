import SwiftUI
import SwiftData
import Charts
import UIKit

@MainActor
struct WorkoutSessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goalPrefill: GoalPrefillStore
    @Environment(\.modelContext) private var modelContext


    @Bindable var session: WorkoutSession

    @StateObject private var logging = WorkoutLoggingService()

    @State private var showFinishConfirm = false
    @State private var showAbandonConfirm = false
    @State private var showRestTimer = false
    @State private var restSecondsToStart = 90
    @State private var activeExerciseID: UUID? = nil
    @State private var activeSetID: UUID? = nil
    @State private var targetAppliedBanner: TargetAppliedBanner? = nil
    
    @State private var coachPrompt: CoachPromptContext? = nil
    @State private var nextTargets: [UUID: PinnedTarget] = [:]
    
    @State private var prToast: PRToast? = nil
    @State private var prBadgesBySetId: [UUID: [CoachSuggestionService.PRAchievement]] = [:]
    @State private var confettiToken: UUID? = nil
    @State private var celebratedPRSetIDs: Set<UUID> = []
    
    @State private var prDetails: PRDetailsContext? = nil
    
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

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    headerSection
                    summarySectionIfReadOnly
                    exercisesSection(proxy: proxy)
                }
                .accessibilityIdentifier("WorkoutSession.Screen")
                .navigationTitle(session.sourceRoutineNameSnapshot ?? "Workout")
                .navigationBarTitleDisplayMode(.inline)
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
                    "Finish workout?",
                    isPresented: $showFinishConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Finish & Save", role: .destructive) { finish() }
                    Button("Keep Logging", role: .cancel) { }
                } message: {
                    Text("This will mark the session as completed.")
                }
                .confirmationDialog(
                    "Abandon session?",
                    isPresented: $showAbandonConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Abandon", role: .destructive) { abandon() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will mark the session as abandoned (not completed).")
                }
                .task(id: session.id) {
                    await applyGoalPrefillIfNeeded()
                    await reloadPinnedTargets()
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
        .sheet(item: $prDetails) { ctx in
            PRDetailsSheetView(ctx: ctx)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("WorkoutSession.Screen")
    }

    private func sessionList(proxy: ScrollViewProxy) -> some View {
        List {
            headerSection
            summarySectionIfReadOnly
            exercisesSection(proxy: proxy)
        }
        .accessibilityIdentifier("WorkoutSession.Screen.List")
        .navigationTitle(session.sourceRoutineNameSnapshot ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) { topInset }
        .safeAreaInset(edge: .bottom) { bottomInset(proxy: proxy) }
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Finish workout?",
            isPresented: $showFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish & Save", role: .destructive) { finish() }
            Button("Keep Logging", role: .cancel) { }
        } message: {
            Text("This will mark the session as completed.")
        }
        .confirmationDialog(
            "Abandon session?",
            isPresented: $showAbandonConfirm,
            titleVisibility: .visible
        ) {
            Button("Abandon", role: .destructive) { abandon() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will mark the session as abandoned (not completed).")
        }
        .task(id: session.id) {
            await applyGoalPrefillIfNeeded()
            await reloadPinnedTargets()
        }
    }

    @ViewBuilder
    private var topInset: some View {
        VStack(spacing: 8) {
            if let prToast {
                PRToastView(
                    title: prToast.title,
                    subtitle: prToast.subtitle,
                    onDismiss: { withAnimation(.snappy) { self.prToast = nil } }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let banner = targetAppliedBanner {
                TargetAppliedBannerView(text: banner.text) {
                    withAnimation(.snappy) { targetAppliedBanner = nil }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: Sections

    private var headerSection: some View {
        Section {
            HStack {
                LabeledContent("Started") {
                    Text(session.startedAt, format: .dateTime.hour().minute())
                }
                Spacer()
                LabeledContent("Status") {
                    Text(statusLabel)
                        .foregroundStyle(session.status == .inProgress ? .secondary : .primary)
                }
            }

            HStack {
                LabeledContent("Elapsed") {
                    Text(timeString(session.elapsedSeconds()))
                        .monospacedDigit()
                }
                Spacer()
                if session.isPaused {
                    Text("Paused").font(.caption).foregroundStyle(.secondary)
                }
            }

            let completedSets = allSets.filter(\.completed).count
            let totalSets = allSets.count

            ProgressView(value: totalSets == 0 ? 0 : Double(completedSets) / Double(totalSets)) {
                Text("Progress")
            } currentValueLabel: {
                Text("\(completedSets)/\(max(totalSets, 1)) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summarySectionIfReadOnly: some View {
        Group {
            if isReadOnly {
                Section("Summary") {
                    let completedSets = allSets.filter(\.completed).count
                    let totalSets = allSets.count

                    let volume = allSets.reduce(0.0) { acc, set in
                        guard set.completed else { return acc }
                        let reps = Double(set.reps ?? 0)
                        let w = set.weight ?? 0
                        return acc + (reps * w)
                    }

                    LabeledContent("Sets") {
                        Text("\(completedSets)/\(totalSets)")
                    }

                    LabeledContent("Volume") {
                        Text(String(format: "%.0f", volume))
                            .foregroundStyle(.secondary)
                    }

                    if let endedAt = session.endedAt {
                        LabeledContent("Ended") {
                            Text(endedAt, format: .dateTime.hour().minute())
                        }
                    }
                }
            }
        }
    }

    // MARK: Data helpers

    private var sortedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { $0.order < $1.order }
    }

    private var allSets: [WorkoutSetLog] {
        sortedExercises.flatMap { sortedSets(for: $0) }
    }

    private func sortedSets(for ex: WorkoutSessionExercise) -> [WorkoutSetLog] {
        ex.setLogs.sorted { $0.order < $1.order }
    }

    private var statusLabel: String {
        switch session.status {
        case .inProgress: return "In progress"
        case .completed: return "Completed"
        case .abandoned: return "Abandoned"
        }
    }

    // MARK: Logging actions

    private func continueLogging(proxy: ScrollViewProxy) {
        if session.isPaused {
            session.resume()
            withAnimation { showRestTimer = false }
            saveOrAssert("resume")
        }

        let exercises = sortedExercises
        guard !exercises.isEmpty else { return }

        guard let targetID = continueNav.nextTargetSetID(
            exercises: exercises,
            activeExerciseID: activeExerciseID,
            activeSetID: activeSetID
        ) else { return }

        // Update cursor so repeated Continue advances predictably.
        if let owningExercise = exercises.first(where: { ex in
            ex.setLogs.contains(where: { $0.id == targetID })
        }) {
            activeExerciseID = owningExercise.id
        }
        activeSetID = targetID

        scrollToSet(targetID, proxy: proxy)
    }

    private func handleSetCompleted(
        ex: WorkoutSessionExercise,
        set: WorkoutSetLog,
        suggestedRest: Int?
    ) {
        guard isInProgress, !session.isPaused else { return }

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
        restSecondsToStart = max(1, prompt.suggestedRestSeconds)
        withAnimation { showRestTimer = true }
    }

    // MARK: View builders

    @ViewBuilder
    private func exercisesSection(proxy: ScrollViewProxy) -> some View {
        if sortedExercises.isEmpty {
            emptyExercisesSection
        } else {
            ForEach(sortedExercises, id: \.id) { ex in
                exerciseSection(ex, proxy: proxy)
            }
        }
    }

    private var emptyExercisesSection: some View {
        Section {
            ContentUnavailableView(
                "No exercises yet",
                systemImage: "dumbbell",
                description: Text("Create routines later. For now you can Quick Start and finish the session.")
            )
        }
    }

    private func exerciseSection(_ ex: WorkoutSessionExercise, proxy: ScrollViewProxy) -> some View {
        Section {
            setsList(for: ex, proxy: proxy)
            addSetButton(for: ex, proxy: proxy)
        } header: {
            VStack(alignment: .leading, spacing: 6) {
                Text(ex.exerciseNameSnapshot)

                if isInProgress, let t = nextTargets[ex.exerciseId] {
                    HStack(spacing: 8) {
                        Text("Next: \(t.text)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Spacer()

                        Button("Apply") {
                            applyPinnedTarget(for: ex)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func setsList(for ex: WorkoutSessionExercise, proxy: ScrollViewProxy) -> some View {
        let sets = sortedSets(for: ex)

        ForEach(sets, id: \.id) { set in
            setRow(ex: ex, set: set, proxy: proxy)
                .id(set.id)
        }
    }

    @ViewBuilder
    private func addSetButton(for ex: WorkoutSessionExercise, proxy: ScrollViewProxy) -> some View {
        if !isReadOnly {
            let sets = sortedSets(for: ex)

            Button {
                markActive(exerciseID: ex.id, setID: nil)
                if let newSet = logging.addSet(to: ex, template: sets.last, context: modelContext) {
                    markActive(exerciseID: ex.id, setID: newSet.id)
                    scrollToSet(newSet.id, proxy: proxy)
                }
            } label: {
                Label("Add set", systemImage: "plus")
            }
        }
    }



    @ViewBuilder
    private func bottomInset(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 10) {
            if showRestTimer && isInProgress && !session.isPaused {
                if let ctx = coachPrompt, isInProgress && !session.isPaused {
                    CoachPromptCardView(
                        title: ctx.prompt.title,
                        message: ctx.prompt.message,
                        suggestedRestSeconds: ctx.prompt.suggestedRestSeconds,
                        weightActionTitle: ctx.prompt.weightLabel.map { "\($0) next set" },
                        repsActionTitle: ctx.prompt.repsLabel.map { "\($0) next set" },
                        onApplyWeight: ctx.prompt.weightDelta == nil ? nil : { applyCoachWeight(ctx, proxy: proxy) },
                        onApplyReps: ctx.prompt.repsDelta == nil ? nil : { applyCoachReps(ctx, proxy: proxy) },
                        onStartRest: {
                            restSecondsToStart = max(1, ctx.prompt.suggestedRestSeconds)
                            withAnimation { showRestTimer = true }
                        },
                        onDismiss: { withAnimation { coachPrompt = nil } }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                RestTimerView(initialSeconds: restSecondsToStart) {
                    withAnimation { showRestTimer = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let toast = logging.undoToast, isInProgress {
                UndoToastView(
                    message: toast.message,
                    onUndo: { logging.undoLast(context: modelContext) },
                    onDismiss: { logging.clearUndoToast() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isInProgress {
                HStack(spacing: 10) {
                    Button {
                        continueLogging(proxy: proxy)
                    } label: {
                        Label(session.isPaused ? "Resume" : "Continue",
                              systemImage: session.isPaused ? "play.fill" : "arrow.down.to.line")
                    }
                    .accessibilityIdentifier("WorkoutSession.ContinueButton")
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if !session.isPaused {
                        Button {
                            session.pause()
                            withAnimation { showRestTimer = false }
                            saveOrAssert("pause")
                        } label: {
                            Image(systemName: "pause.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel("Pause")
                    }

                    Button {
                        showFinishConfirm = true
                    } label: {
                        Label("Finish", systemImage: "checkmark.circle")
                    }
                    .accessibilityIdentifier("WorkoutSession.FinishButton")
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isInProgress {
                Button { withAnimation { showRestTimer.toggle() } } label: {
                    Image(systemName: "timer")
                }
                .disabled(session.isPaused)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if isInProgress {
                Menu {
                    Button("Abandon", systemImage: "xmark.circle", role: .destructive) {
                        showAbandonConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            } else {
                Button("Close") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: Finish/abandon

    private func finish() {
        if session.isPaused { session.resume() }
        session.endedAt = Date()
        session.status = .completed
        saveOrAssert("finish")
        dismiss()
    }

    private func abandon() {
        if session.isPaused { session.resume() }
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

    private func timeString(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
    
    private func markActive(exerciseID: UUID, setID: UUID?) {
        activeExerciseID = exerciseID
        activeSetID = setID
    }
    
    @ViewBuilder
    private func setRow(ex: WorkoutSessionExercise, set: WorkoutSetLog, proxy: ScrollViewProxy) -> some View {
        WorkoutSetEditorRow(
            set: set,
            setNumber: set.order + 1,
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
                if !isReadOnly, let newSet = logging.copySet(set, in: ex, context: modelContext) {
                    markActive(exerciseID: ex.id, setID: newSet.id)
                    scrollToSet(newSet.id, proxy: proxy)
                }
            },
            onAddSet: {
                markActive(exerciseID: ex.id, setID: set.id)
                if !isReadOnly, let newSet = logging.addSet(to: ex, after: set, template: set, context: modelContext) {
                    markActive(exerciseID: ex.id, setID: newSet.id)
                    scrollToSet(newSet.id, proxy: proxy)
                }
            },
            onDeleteSet: {
                markActive(exerciseID: ex.id, setID: set.id)
                if !isReadOnly {
                    logging.deleteSet(set, from: ex, context: modelContext)
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
                        setNumber: set.order + 1,
                        achievements: ach,
                        weight: set.weight,
                        reps: set.reps,
                        unit: set.weightUnit.rawValue
                    )
                } label: {
                    Text("PR")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.yellow.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .accessibilityLabel("Show PR details")
            }
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
            ? bannerMessageApplied(target: target, setNumber: set.order + 1, unit: set.weightUnit.rawValue)
            : "Target already filled — nothing changed."

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
        if let r = target.reps { parts.append("\(r) reps") }

        if parts.isEmpty {
            return "Target applied to Set \(setNumber)."
        } else {
            return "Target applied to Set \(setNumber): " + parts.joined(separator: " • ")
        }
    }

    private func formatWeight(_ w: Double) -> String {
        if w.rounded() == w { return String(Int(w)) }
        return String(format: "%.1f", w)
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
    
    private func scrollToSet(_ id: UUID, proxy: ScrollViewProxy) {
        dismissKeyboard()
        DispatchQueue.main.async {
            withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
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
        var sets = sortedSets(for: ex)
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
        scrollToSet(next.id, proxy: proxy)
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
        scrollToSet(next.id, proxy: proxy)
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
        let headline = "PR!"
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
                                Text("Set \(ctx.setNumber)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                if let w = ctx.weight {
                                    Text("\(formatWeight(w)) \(ctx.unit)")
                                        .font(.subheadline.weight(.semibold))
                                }
                                if let r = ctx.reps {
                                    Text("\(r) reps")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Personal Records") {
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
                .navigationTitle("PR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }

        private func formatWeight(_ w: Double) -> String {
            w.rounded() == w ? String(Int(w)) : String(format: "%.1f", w)
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
    
    private enum Haptics {
        static func success() {
    #if canImport(UIKit)
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.success)
    #endif
        }
    }
}
