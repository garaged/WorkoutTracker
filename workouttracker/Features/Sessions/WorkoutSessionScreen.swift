import SwiftUI
import SwiftData

@MainActor
struct WorkoutSessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var session: WorkoutSession

    @State private var showFinishConfirm = false
    @State private var showAbandonConfirm = false
    @State private var showRestTimer = false
    @State private var restSecondsToStart = 90

    private var isReadOnly: Bool { session.status != .inProgress }

    var body: some View {
        List {
            headerSection
            summarySectionIfReadOnly

            ForEach(sortedExercises) { ex in
                Section {
                    ForEach(sortedSets(for: ex)) { set in
                        WorkoutSetEditorRow(
                            set: set,
                            setNumber: set.order + 1,
                            isReadOnly: isReadOnly
                        ) { suggestedRest in
                            guard session.status == .inProgress, !session.isPaused else { return }
                            restSecondsToStart = max(1, suggestedRest ?? 90)
                            withAnimation { showRestTimer = true }
                        }
                    }

                    if !isReadOnly {
                        Button {
                            addSet(to: ex)
                        } label: {
                            Label("Add set", systemImage: "plus")
                        }
                    }
                } header: {
                    Text(ex.exerciseNameSnapshot)
                }
            }
        }
        .navigationTitle(session.sourceRoutineNameSnapshot ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if showRestTimer && session.status == .inProgress && !session.isPaused {
                RestTimerView(initialSeconds: restSecondsToStart) {
                    withAnimation { showRestTimer = false }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if session.status == .inProgress {
                    Button { withAnimation { showRestTimer.toggle() } } label: {
                        Image(systemName: "timer")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if session.status == .inProgress {
                    Menu {
                        Button("Finish", systemImage: "checkmark.circle") {
                            showFinishConfirm = true
                        }
                        Button("Abandon", systemImage: "xmark.circle", role: .destructive) {
                            showAbandonConfirm = true
                        }
                    } label: {
                        Text("Done").fontWeight(.semibold)
                    }
                } else {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }

            ToolbarItem(placement: .bottomBar) {
                if session.status == .inProgress {
                    Button {
                        if session.isPaused {
                            session.resume()
                        } else {
                            session.pause()
                            withAnimation { showRestTimer = false }
                        }
                        saveOrAssert("pause/resume")
                    } label: {
                        Label(session.isPaused ? "Resume" : "Pause",
                              systemImage: session.isPaused ? "play.fill" : "pause.fill")
                    }
                }
            }
        }
        .confirmationDialog("Finish workout?",
                            isPresented: $showFinishConfirm,
                            titleVisibility: .visible) {
            Button("Finish & Save", role: .destructive) { finish() }
            Button("Keep Logging", role: .cancel) { }
        } message: {
            Text("This will mark the session as completed.")
        }
        .confirmationDialog("Abandon session?",
                            isPresented: $showAbandonConfirm,
                            titleVisibility: .visible) {
            Button("Abandon", role: .destructive) { abandon() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will mark the session as abandoned (not completed).")
        }
        
        if session.exercises.isEmpty {
            Section {
                ContentUnavailableView(
                    "No exercises yet",
                    systemImage: "dumbbell",
                    description: Text("Create routines later. For now you can Quick Start and finish the session.")
                )
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

    // MARK: Actions

    private func addSet(to ex: WorkoutSessionExercise) {
        let nextOrder = (ex.setLogs.map(\.order).max() ?? -1) + 1
        let newSet = WorkoutSetLog(
            order: nextOrder,
            origin: .planned, // safe default; adjust if you have a better “manual” origin
            reps: ex.setLogs.last?.targetReps,
            weight: ex.setLogs.last?.targetWeight,
            weightUnit: ex.setLogs.last?.targetWeightUnit ?? .kg,
            rpe: ex.setLogs.last?.targetRPE,
            completed: false,
            targetReps: ex.setLogs.last?.targetReps,
            targetWeight: ex.setLogs.last?.targetWeight,
            targetWeightUnit: ex.setLogs.last?.targetWeightUnit ?? .kg,
            targetRPE: ex.setLogs.last?.targetRPE,
            targetRestSeconds: ex.setLogs.last?.targetRestSeconds,
            sessionExercise: ex
        )

        ex.setLogs.append(newSet)
        saveOrAssert("add set")
    }

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
