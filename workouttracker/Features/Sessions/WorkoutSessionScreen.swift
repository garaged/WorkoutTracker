import SwiftUI
import SwiftData
import UIKit

@MainActor
struct WorkoutSessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var session: WorkoutSession

    @StateObject private var logging = WorkoutLoggingService()

    @State private var showFinishConfirm = false
    @State private var showAbandonConfirm = false
    @State private var showRestTimer = false
    @State private var restSecondsToStart = 90
    @State private var activeExerciseID: UUID? = nil
    @State private var activeSetID: UUID? = nil


    private var isReadOnly: Bool { session.status != .inProgress }
    private var isInProgress: Bool { session.status == .inProgress }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                headerSection
                summarySectionIfReadOnly
                exercisesSection(proxy: proxy)
            }
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
        }
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

        // Find the active exercise (last interacted), else default to first.
        let activeIndex = activeExerciseID.flatMap { id in
            exercises.firstIndex(where: { $0.id == id })
        } ?? 0

        func nextIncompleteSetID(in ex: WorkoutSessionExercise, after setID: UUID?) -> UUID? {
            let sets = ex.setLogs.sorted(by: { $0.order < $1.order })
            guard !sets.isEmpty else { return nil }

            let startIndex = setID.flatMap { sid in sets.firstIndex(where: { $0.id == sid }) }

            // Prefer the next incomplete strictly AFTER the cursor.
            if let startIndex, startIndex + 1 < sets.count {
                if let found = sets[(startIndex + 1)...].first(where: { !$0.completed }) {
                    return found.id
                }
            }

            // Otherwise wrap to the first incomplete in this exercise.
            return sets.first(where: { !$0.completed })?.id
        }

        // Track both: which exercise we picked and which set inside it.
        var targetExercise: WorkoutSessionExercise? = nil
        var targetSetID: UUID? = nil

        // 1) Prefer next incomplete in the active exercise (relative to activeSetID).
        if let id = nextIncompleteSetID(in: exercises[activeIndex], after: activeSetID) {
            targetExercise = exercises[activeIndex]
            targetSetID = id
        }

        // 2) If none in active exercise, advance forward to the next exercise that has incomplete sets.
        if targetSetID == nil, activeIndex + 1 < exercises.count {
            for i in (activeIndex + 1)..<exercises.count {
                if let id = nextIncompleteSetID(in: exercises[i], after: nil) {
                    targetExercise = exercises[i]
                    targetSetID = id
                    break
                }
            }
        }

        // 3) If still none, fall back to first incomplete anywhere.
        if targetSetID == nil {
            for ex in exercises {
                if let id = nextIncompleteSetID(in: ex, after: nil) {
                    targetExercise = ex
                    targetSetID = id
                    break
                }
            }
        }

        // Final fallback: last set (end of list).
        if targetSetID == nil {
            targetSetID = allSets.last?.id
            targetExercise = exercises.first(where: { ex in
                ex.setLogs.contains(where: { $0.id == targetSetID })
            })
        }

        guard let targetID = targetSetID else { return }

        // ✅ Critical: update cursor so repeated "Continue" taps keep advancing.
        if let targetExercise {
            activeExerciseID = targetExercise.id
        }
        activeSetID = targetID
        
        dismissKeyboard()

        DispatchQueue.main.async {
            withAnimation(.snappy) {
                proxy.scrollTo(targetID, anchor: .center)
            }
        }
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
            Section {
                ContentUnavailableView(
                    "No exercises yet",
                    systemImage: "dumbbell",
                    description: Text("Create routines later. For now you can Quick Start and finish the session.")
                )
            }
        } else {
            ForEach(sortedExercises) { ex in
                Section {
                    let sets = sortedSets(for: ex)

                    ForEach(Array(sets.enumerated()), id: \.element.id) { _, set in
                        WorkoutSetEditorRow(
                            set: set,
                            setNumber: set.order + 1,
                            isReadOnly: isReadOnly,
                            onCompleted: handleSetCompleted(_:),
                            onPersist: {
                                activeExerciseID = ex.id
                                activeSetID = set.id
                                saveOrAssert("set edit")
                            },

                            // Fast tap actions back to the service.
                            onToggleComplete: {
                                activeExerciseID = ex.id
                                activeSetID = set.id
                                logging.toggleCompleted(set, context: modelContext)
                            },
                            onCopySet: {
                                activeExerciseID = ex.id
                                activeSetID = set.id
                                guard !isReadOnly else { return }
                                if let newSet = logging.copySet(set, in: ex, context: modelContext) {
                                    activeSetID = newSet.id
                                    dismissKeyboard()
                                    DispatchQueue.main.async {
                                        withAnimation(.snappy) { proxy.scrollTo(newSet.id, anchor: .center) }
                                    }
                                }
                            },
                            onAddSet: {
                                activeExerciseID = ex.id
                                activeSetID = set.id
                                guard !isReadOnly else { return }
                                if let newSet = logging.addSet(to: ex, after: set, template: set, context: modelContext) {
                                    activeSetID = newSet.id
                                    dismissKeyboard()
                                    DispatchQueue.main.async {
                                        withAnimation(.snappy) { proxy.scrollTo(newSet.id, anchor: .center) }
                                    }
                                }
                            },
                            onDeleteSet: {
                                activeExerciseID = ex.id
                                activeSetID = set.id
                                guard !isReadOnly else { return }
                                logging.deleteSet(set, from: ex, context: modelContext)
                            },

                            onBumpReps: { delta in
                                activeExerciseID = ex.id
                                activeSetID = set.id
                                guard !isReadOnly else { return }
                                logging.bumpReps(set, delta: delta, context: modelContext)
                            },

                            onBumpWeight: { delta in
                                activeExerciseID = ex.id
                                activeSetID = set.id
                                guard !isReadOnly else { return }
                                logging.bumpWeight(set, delta: delta, context: modelContext)
                            },
                            weightStep: 1.0
                        )
                        .id(set.id)
                    }

                    if !isReadOnly {
                        Button {
                            activeExerciseID = ex.id
                            if let newSet = logging.addSet(to: ex, template: sets.last, context: modelContext) {
                                activeSetID = newSet.id
                                DispatchQueue.main.async {
                                    withAnimation(.snappy) { proxy.scrollTo(newSet.id, anchor: .center) }
                                }
                            }
                        } label: {
                            Label("Add set", systemImage: "plus")
                        }
                    }
                } header: {
                    Text(ex.exerciseNameSnapshot)
                }
            }
        }
    }

    private func dismissKeyboard() {
    #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    #endif
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
}

// Makes `.sheet(item:)` happy in other screens
extension WorkoutSession: Identifiable {}
extension WorkoutSessionExercise: Identifiable {}
extension WorkoutSetLog: Identifiable {}
