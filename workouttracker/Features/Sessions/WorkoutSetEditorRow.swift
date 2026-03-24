import SwiftUI
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

    @AppStorage(UnitPreferences.Keys.weightUnitRaw)
    private var preferredUnitRaw: String = WeightUnit.kg.rawValue

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var preferredUnit: WeightUnit {
        WeightUnit(rawValue: preferredUnitRaw) ?? .kg
    }

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var stacksEditorsVertically: Bool {
        AdaptiveLayoutMetrics.shouldStackSetEditorFields(
            horizontalSizeClass: horizontalSizeClass,
            dynamicTypeSize: dynamicTypeSize
        )
    }
    private var repsFieldWidth: CGFloat {
        AdaptiveLayoutMetrics.compactFieldWidth(base: isCompact ? 54 : 62, dynamicTypeSize: dynamicTypeSize)
    }
    private var weightFieldWidth: CGFloat {
        AdaptiveLayoutMetrics.compactFieldWidth(base: isCompact ? 68 : 84, dynamicTypeSize: dynamicTypeSize)
    }

    let setNumber: Int
    let isReadOnly: Bool
    var accessibilityStateText: String? = nil

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

    /// UI-only tuning: default weight step if you do not provide a custom one.
    var weightStep: Double = 2.5

    @State private var persistDebounceTask: Task<Void, Never>?

    /// Used to make accessibility identifiers unique per row.
    /// This keeps UI tests deterministic even when multiple sets are on screen.
    private var a11yPrefix: String { "WorkoutSetEditorRow.\(set.id.uuidString)" }

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
        preferredWeightBinding(for: set)
    }

    private func preferredWeightBinding(for set: WorkoutSetLog) -> Binding<String> {
        Binding(
            get: {
                guard let w = set.weight(in: preferredUnit) else { return "" }
                return w.rounded() == w ? String(Int(w)) : String(format: "%.1f", w)
            },
            set: { txt in
                let t = txt.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty {
                    set.setWeight(nil, preferredUnit: preferredUnit)
                    schedulePersist()
                    return
                }

                let v = Double(t.replacingOccurrences(of: ",", with: ".")) ?? 0
                set.setWeight(v == 0 ? nil : v, preferredUnit: preferredUnit)
                schedulePersist()
            }
        )
    }

    private var targetHint: String? {
        var parts: [String] = []
        if let tr = set.targetReps { parts.append("\(tr) \(String(localized: "Reps"))") }
        if let tw = set.targetWeight(in: preferredUnit) {
            parts.append("@ \(formatWeight(tw)) \(preferredUnit.label)")
        }
        if let r = set.targetRPE { parts.append("RPE \(formatRPE(r))") }
        guard !parts.isEmpty else { return nil }
        return "Target: " + parts.joined(separator: " ")
    }

    private var rowAccessibilityValue: String {
        AccessibilityLabels.SessionSet.rowValue(
            repsText: repsBinding.wrappedValue,
            weightText: weightBinding.wrappedValue,
            unit: preferredUnit.label,
            targetHint: targetHint.map(AccessibilityLabels.SessionSet.targetValue),
            stateText: accessibilityStateText
        )
    }

    var body: some View {
        HStack(alignment: stacksEditorsVertically ? .top : .center, spacing: 8) {
            Text("\(setNumber)")
                .font(.headline)
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(set.completed ? .secondary : .primary)
                .layoutPriority(2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                editorsBlock

                if let hint = targetHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(stacksEditorsVertically ? 2 : 1)
                        .minimumScaleFactor(0.85)
                }

                SetRowActionsBar(
                    isReadOnly: isReadOnly,
                    onAction: { action in
                        switch action {
                        case .copy:
                            onCopySet?()
                        case .add:
                            onAddSet?()
                        case .delete:
                            onDeleteSet?()
                        }
                    },
                    idPrefix: "\(a11yPrefix).Actions"
                )
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Button {
                toggleDone()
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(set.completed ? .green : .secondary)
                    .accessibilityDecorative()
            }
            .buttonStyle(.plain)
            .frame(width: 44, alignment: .trailing)
            .layoutPriority(2)
            .disabled(isReadOnly)
            .accessibilityIconControl(
                label: AccessibilityLabels.SessionSet.doneToggleLabel(isCompleted: set.completed),
                hint: accessibilityStateText,
                identifier: "\(a11yPrefix).DoneToggle"
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AccessibilityLabels.SessionSet.rowLabel(setNumber: setNumber))
        .accessibilityValue(rowAccessibilityValue)
        .accessibilityIdentifier("\(a11yPrefix).Row")
        .padding(.vertical, 6)
        .onDisappear {
            persistDebounceTask?.cancel()
            persistDebounceTask = nil
            onPersist?()
        }
    }

    private var editorsBlock: some View {
        Group {
            if stacksEditorsVertically {
                VStack(alignment: .leading, spacing: 10) {
                    repsEditor
                    weightEditor
                }
            } else {
                HStack(alignment: .top, spacing: isCompact ? 8 : 12) {
                    repsEditor
                    weightEditor
                }
            }
        }
    }

    private var repsEditor: some View {
        valueEditor(
            title: String(localized: "Reps"),
            accessibilityFieldLabel: AccessibilityLabels.Fields.reps,
            text: repsBinding,
            keyboard: .numberPad,
            width: repsFieldWidth,
            minusAccessibilityLabel: AccessibilityLabels.Buttons.decreaseReps,
            plusAccessibilityLabel: AccessibilityLabels.Buttons.increaseReps,
            minus: { bumpReps(-1) },
            plus: { bumpReps(+1) },
            idBase: "\(a11yPrefix).Reps"
        )
    }

    private var weightEditor: some View {
        valueEditor(
            title: isCompact ? "Wt (\(preferredUnit.label))" : String(localized: "Weight"),
            accessibilityFieldLabel: AccessibilityLabels.Fields.weight(unit: preferredUnit.label),
            text: weightBinding,
            keyboard: .decimalPad,
            width: weightFieldWidth,
            minusAccessibilityLabel: AccessibilityLabels.Buttons.decreaseWeight(unit: preferredUnit.label),
            plusAccessibilityLabel: AccessibilityLabels.Buttons.increaseWeight(unit: preferredUnit.label),
            minus: { bumpWeight(-weightStep) },
            plus: { bumpWeight(+weightStep) },
            trailing: isCompact ? nil : AnyView(
                Text(preferredUnit.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            ),
            idBase: "\(a11yPrefix).Weight"
        )
    }

    // MARK: - Actions

    private func toggleDone() {
        let wasCompleted = set.completed

        if let onToggleComplete {
            onToggleComplete()
            DispatchQueue.main.async {
                if !wasCompleted && set.completed {
                    fireCompletionHaptic()
                    onCompleted?(set.targetRestSeconds)
                }
            }
            return
        }

        set.completed.toggle()
        set.completedAt = set.completed ? Date() : nil
        onPersist?()

        if !wasCompleted && set.completed {
            fireCompletionHaptic()
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
            let curPreferred = set.weight(in: preferredUnit) ?? 0
            let nextPreferred = max(0, curPreferred + delta)
            set.setWeight(nextPreferred == 0 ? nil : nextPreferred, preferredUnit: preferredUnit)
            onPersist?()
        }
    }

    private func schedulePersist() {
        guard !isReadOnly else { return }
        guard let onPersist else { return }

        persistDebounceTask?.cancel()
        persistDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await MainActor.run { onPersist() }
        }
    }

    // MARK: - Subviews

    private func valueEditor(
        title: String,
        accessibilityFieldLabel: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        width: CGFloat,
        minusAccessibilityLabel: String,
        plusAccessibilityLabel: String,
        minus: @escaping () -> Void,
        plus: @escaping () -> Void,
        trailing: AnyView? = nil,
        idBase: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            HStack(spacing: 6) {
                StepIconButton(
                    systemName: "minus.circle",
                    action: minus,
                    accessibilityLabel: minusAccessibilityLabel,
                    accessibilityID: "\(idBase).Minus"
                )
                .disabled(isReadOnly)

                TextField("—", text: text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
                    .frame(width: width)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isReadOnly)
                    .accessibilityLabel(accessibilityFieldLabel)
                    .accessibilityIdentifier("\(idBase).Field")

                StepIconButton(
                    systemName: "plus.circle",
                    action: plus,
                    accessibilityLabel: plusAccessibilityLabel,
                    accessibilityID: "\(idBase).Plus"
                )
                .disabled(isReadOnly)

                if let trailing { trailing }
            }
        }
    }

    private struct StepIconButton: View {
        let systemName: String
        let action: () -> Void
        let accessibilityLabel: String
        let accessibilityID: String

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityDecorative()
            }
            .buttonStyle(.plain)
            .accessibilityIconControl(label: accessibilityLabel, identifier: accessibilityID)
        }
    }

    private func formatWeight(_ w: Double) -> String {
        if w.rounded() == w { return String(Int(w)) }
        return String(w)
    }

    private func formatRPE(_ r: Double) -> String {
        if r.rounded() == r { return String(Int(r)) }
        return String(r)
    }

    private func fireCompletionHaptic() {
    #if canImport(UIKit)
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    #endif
    }
}
