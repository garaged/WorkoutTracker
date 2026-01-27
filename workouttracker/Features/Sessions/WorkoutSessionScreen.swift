import SwiftUI
import SwiftData

@MainActor
struct WorkoutSessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GoalPrefillStore.self) private var goalPrefill
    @Environment(\.modelContext) private var modelContext


    @Bindable var session: WorkoutSession

    @StateObject private var logging = WorkoutLoggingService()

    @State private var showFinishConfirm = false
    @State private var showAbandonConfirm = false
    @State private var showRestTimer = false
    @State private var restSecondsToStart = 90
    @State private var activeExerciseID: UUID? = nil
    @State private var activeSetID: UUID? = nil
    
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
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("WorkoutSession.Screen")
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
        sortedExercises.flatMap { $0.setLogs }.sorted { $0.order < $1.order }
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


    private func handleSetCompleted(_ suggestedRest: Int?) {
        guard isInProgress, !session.isPaused else { return }
        restSecondsToStart = max(1, suggestedRest ?? 90)
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
            Text(ex.exerciseNameSnapshot)
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
            onCompleted: handleSetCompleted(_:),
            onPersist: {
                markActive(exerciseID: ex.id, setID: set.id)
                saveOrAssert("set edit")
            },

            onToggleComplete: {
                markActive(exerciseID: ex.id, setID: set.id)
                logging.toggleCompleted(set, context: modelContext)
            },

            // ✅ order matters: onCopySet BEFORE onAddSet
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
                if !isReadOnly {
                    logging.bumpReps(set, delta: delta, context: modelContext)
                }
            },

            onBumpWeight: { delta in
                markActive(exerciseID: ex.id, setID: set.id)
                if !isReadOnly {
                    logging.bumpWeight(set, delta: delta, context: modelContext)
                }
            },

            weightStep: 2.5
        )
    }
    
    @MainActor
    private func applyGoalPrefillIfNeeded() async {
        guard session.status == .inProgress else { return }
        guard let exId = goalPrefill.pendingExerciseId else { return }
        guard let target = goalPrefill.consumeIfMatches(exerciseId: exId) else { return }

        guard let ex = session.exercises.first(where: { $0.exerciseId == exId }) else { return }
        guard let set = ex.setLogs.first(where: { !$0.completed }) else { return }

        // Only prefill if user hasn't already typed something
        if let w = target.weight, (set.weight ?? 0) == 0 { set.weight = w }
        if let r = target.reps, (set.reps ?? 0) == 0 { set.reps = r }

        try? modelContext.save()
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
}
