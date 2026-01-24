import SwiftUI
import SwiftData
import UIKit

/// Fast inline editing for reps/weight + done toggle.
/// Aligned to `WorkoutSetLog` (completed/targetRestSeconds/weightUnit).
///
/// Changes for "tap-tap-done":
/// - plus/minus steppers for reps + weight (so you rarely open the keyboard)
/// - mini action bar: copy set, +1 set, delete
/// - clearer "done" state
struct WorkoutSetEditorRow: View {
    @Bindable var set: WorkoutSetLog

    let setNumber: Int
    let isReadOnly: Bool

    /// Called only when a set transitions from not-done -> done. Parameter is suggested rest seconds.
    var onCompleted: ((Int?) -> Void)? = nil

    /// Called when the user edits fields directly (TextFields). Keep this light (save context).
    var onPersist: (() -> Void)? = nil

    // Actions (typically backed by `WorkoutLoggingService` in the parent screen)
    var onToggleComplete: (() -> Void)? = nil
    var onCopySet: (() -> Void)? = nil
    var onAddSet: (() -> Void)? = nil
    var onDeleteSet: (() -> Void)? = nil
    var onBumpReps: ((Int) -> Void)? = nil
    var onBumpWeight: ((Double) -> Void)? = nil

    /// UI-only tuning: default weight step if you don't provide a custom one.
    var weightStep: Double = 2.5

    @State private var persistDebounceTask: Task<Void, Never>?

    private var repsBinding: Binding<String> {
        Binding<String>(
            get: { set.reps.map(String.init) ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                set.reps = Int(trimmed)
                schedulePersist()
            }
        )
    }

    private var weightBinding: Binding<String> {
        Binding<String>(
            get: {
                guard let w = set.weight else { return "" }
                if w.rounded() == w { return String(Int(w)) }
                return String(w)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { set.weight = nil; schedulePersist(); return }
                let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                set.weight = Double(normalized)
                schedulePersist()
            }
        )
    }

    private var targetHint: String? {
        var parts: [String] = []
        if let tr = set.targetReps { parts.append("\(tr) reps") }
        if let tw = set.targetWeight { parts.append("@ \(formatWeight(tw)) \(set.targetWeightUnit.rawValue)") }
        if let r = set.targetRPE { parts.append("RPE \(formatRPE(r))") }
        guard !parts.isEmpty else { return nil }
        return "Target: " + parts.joined(separator: " ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 4) {
                Text("\(setNumber)")
                    .font(.headline)
                    .frame(width: 28, alignment: .leading)
                    .foregroundStyle(set.completed ? .secondary : .primary)

                if set.completed {
                    Text("DONE")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Done")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    valueEditor(
                        title: "Reps",
                        text: repsBinding,
                        keyboard: .numberPad,
                        width: 62,
                        minus: { bumpReps(-1) },
                        plus: { bumpReps(+1) }
                    )

                    valueEditor(
                        title: "Weight",
                        text: weightBinding,
                        keyboard: .decimalPad,
                        width: 84,
                        minus: { bumpWeight(-weightStep) },
                        plus: { bumpWeight(+weightStep) },
                        trailing: AnyView(
                            Text(set.weightUnit.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        )
                    )
                }

                if let hint = targetHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                SetRowActionsBar(
                    isReadOnly: isReadOnly,
                    onCopy: onCopySet,
                    onAdd: onAddSet,
                    onDelete: onDeleteSet
                )
            }

            Spacer()

            Button {
                toggleDone()
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(isReadOnly)
            .accessibilityLabel(set.completed ? "Mark set not completed" : "Mark set completed")
        }
        .padding(.vertical, 6)
        .opacity(set.completed ? 0.92 : 1.0)
        .onDisappear { persistDebounceTask?.cancel() }
    }

    // MARK: - Actions

    private func toggleDone() {
        let wasCompleted = set.completed

        if let onToggleComplete {
            onToggleComplete()
        } else {
            set.completed.toggle()
            set.completedAt = set.completed ? Date() : nil
            onPersist?()
        }

        // If we transitioned false -> true, trigger rest suggestion.
        if !wasCompleted && set.completed {
            onCompleted?(set.targetRestSeconds)
        }
    }

    private func bumpReps(_ delta: Int) {
        guard !isReadOnly else { return }
        if let onBumpReps {
            onBumpReps(delta)
        } else {
            let cur = set.reps ?? 0
            set.reps = max(0, cur + delta)
            onPersist?()
        }
    }

    private func bumpWeight(_ delta: Double) {
        guard !isReadOnly else { return }
        if let onBumpWeight {
            onBumpWeight(delta)
        } else {
            let cur = set.weight ?? 0
            let next = max(0, cur + delta)
            set.weight = next == 0 ? nil : next
            onPersist?()
        }
    }

    private func schedulePersist() {
        guard !isReadOnly else { return }
        guard let onPersist else { return }

        persistDebounceTask?.cancel()
        persistDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // ~0.35s debounce
            if Task.isCancelled { return }
            await MainActor.run { onPersist() }
        }
    }

    // MARK: - Subviews

    private func valueEditor(
        title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        width: CGFloat,
        minus: @escaping () -> Void,
        plus: @escaping () -> Void,
        trailing: AnyView? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                StepIconButton(systemName: "minus.circle", action: minus)
                    .disabled(isReadOnly)

                TextField("—", text: text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
                    .frame(width: width)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isReadOnly)

                StepIconButton(systemName: "plus.circle", action: plus)
                    .disabled(isReadOnly)

                if let trailing { trailing }
            }
        }
    }

    private struct StepIconButton: View {
        let systemName: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Formatting

    private func formatWeight(_ w: Double) -> String {
        if w.rounded() == w { return String(Int(w)) }
        return String(w)
    }

    private func formatRPE(_ r: Double) -> String {
        if r.rounded() == r { return String(Int(r)) }
        return String(r)
    }
}
