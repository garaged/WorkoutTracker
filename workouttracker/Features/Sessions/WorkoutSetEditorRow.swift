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
    private var repsFieldMinWidth: CGFloat {
        AdaptiveLayoutMetrics.compactFieldWidth(base: isCompact ? 44 : 58, dynamicTypeSize: dynamicTypeSize)
    }
    private var weightFieldMinWidth: CGFloat {
        AdaptiveLayoutMetrics.compactFieldWidth(base: isCompact ? 56 : 78, dynamicTypeSize: dynamicTypeSize)
    }
    private var editorSpacing: CGFloat {
        isCompact ? 8 : 12
    }
    private var usesExpandedDoneControl: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    private var compactControlVisualSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 44 : (isCompact ? 32 : 36)
    }
    private var doneControlWidth: CGFloat {
        usesExpandedDoneControl ? 92 : (isCompact ? 34 : 40)
    }
    private var rowNumberWidth: CGFloat {
        isCompact ? 20 : 28
    }

    let setNumber: Int
    let isReadOnly: Bool
    var accessibilityStateText: String? = nil

    /// Called only when a set transitions from not-done -> done. Parameter is suggested rest seconds.
    var onCompleted: ((Int?) -> Void)? = nil

    /// Called when the user edits row values. The row debounces text-entry saves and only flushes on disappear when edits are still pending.
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
    @State private var hasPendingPersist = false
    @State private var trackedSetID: UUID?
    @State private var lastPersistedState: PersistedRowState?

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
                .frame(width: rowNumberWidth, alignment: .leading)
                .foregroundStyle(set.completed ? .secondary : .primary)
                .layoutPriority(2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
                editorsBlock
                supportingContent
            }
            .layoutPriority(1)

            doneToggleButton
                .frame(width: doneControlWidth, alignment: .trailing)
                .frame(minHeight: compactControlVisualSize)
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
        .padding(.vertical, isCompact ? 4 : 6)
        .onAppear {
            synchronizePersistTrackingBaseline()
        }
        .onDisappear {
            cancelPersistDebounce()
            flushPendingPersistIfNeeded()
        }
    }

    @ViewBuilder
    private var doneToggleButton: some View {
        let baseButton = Button {
            toggleDone()
        } label: {
            Group {
                if usesExpandedDoneControl {
                    Label(
                        set.completed ? String(localized: "common.done") : String(localized: "a11y.button.mark_complete"),
                        systemImage: set.completed ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.subheadline.weight(.semibold))
                } else {
                    Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                        .font(isCompact ? .title3 : .title2)
                }
            }
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(set.completed ? .green : .secondary)
            .accessibilityDecorative()
        }

        if usesExpandedDoneControl {
            baseButton.buttonStyle(.bordered)
        } else {
            baseButton.buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var editorsBlock: some View {
        if stacksEditorsVertically {
            VStack(alignment: .leading, spacing: 6) {
                repsEditor
                weightEditor
            }
        } else {
            WeightedEditorRowLayout(weights: AdaptiveLayoutMetrics.setEditorMiddleWeights, spacing: editorSpacing) {
                repsEditor
                weightEditor
            }
        }
    }

    @ViewBuilder
    private var supportingContent: some View {
        if let hint = targetHint {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    Text(hint)
                        .font(isCompact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    rowActions
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(hint)
                        .font(isCompact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    rowActions
                }
            }
        } else {
            rowActions
        }
    }

    private var rowActions: some View {
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

    private var repsEditor: some View {
        valueEditor(
            title: String(localized: "Reps"),
            accessibilityFieldLabel: AccessibilityLabels.Fields.reps,
            text: repsBinding,
            keyboard: .numberPad,
            width: repsFieldMinWidth,
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
            width: weightFieldMinWidth,
            minusAccessibilityLabel: AccessibilityLabels.Buttons.decreaseWeight(unit: preferredUnit.label),
            plusAccessibilityLabel: AccessibilityLabels.Buttons.increaseWeight(unit: preferredUnit.label),
            minus: { bumpWeight(-weightStep) },
            plus: { bumpWeight(+weightStep) },
            trailing: isCompact ? nil : AnyView(
                Text(preferredUnit.label)
                    .font(isCompact ? .caption2 : .caption)
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
        persistImmediatelyIfNeeded()

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
            schedulePersistIfNeeded()
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
            schedulePersistIfNeeded()
        }
    }

    private func schedulePersist() {
        schedulePersistIfNeeded()
    }

    private func schedulePersistIfNeeded() {
        guard !isReadOnly else { return }
        synchronizePersistTrackingBaseline()
        guard let onPersist else { return }

        let currentState = currentPersistedState()
        guard currentState != lastPersistedState else {
            hasPendingPersist = false
            cancelPersistDebounce()
            return
        }

        hasPendingPersist = true
        cancelPersistDebounce()
        persistDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                onPersist()
                lastPersistedState = currentPersistedState()
                hasPendingPersist = false
                persistDebounceTask = nil
            }
        }
    }

    private func persistImmediatelyIfNeeded() {
        guard !isReadOnly else { return }
        synchronizePersistTrackingBaseline()
        guard let onPersist else { return }

        let currentState = currentPersistedState()
        guard currentState != lastPersistedState else { return }

        cancelPersistDebounce()
        onPersist()
        lastPersistedState = currentPersistedState()
        hasPendingPersist = false
    }

    private func flushPendingPersistIfNeeded() {
        guard hasPendingPersist else { return }
        persistImmediatelyIfNeeded()
    }

    private func cancelPersistDebounce() {
        persistDebounceTask?.cancel()
        persistDebounceTask = nil
    }

    private func synchronizePersistTrackingBaseline() {
        let currentSetID = set.id
        guard trackedSetID != currentSetID || lastPersistedState == nil else { return }
        trackedSetID = currentSetID
        lastPersistedState = currentPersistedState()
        hasPendingPersist = false
        cancelPersistDebounce()
    }

    private func currentPersistedState() -> PersistedRowState {
        PersistedRowState(
            reps: set.reps,
            weight: set.weight,
            weightUnitRaw: set.weightUnit.rawValue,
            completed: set.completed,
            completedAt: set.completedAt
        )
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
        VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
            Text(title)
                .font(isCompact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            HStack(spacing: isCompact ? 4 : 6) {
                StepIconButton(
                    systemName: "minus.circle",
                    action: minus,
                    accessibilityLabel: minusAccessibilityLabel,
                    accessibilityID: "\(idBase).Minus",
                    visualSize: compactControlVisualSize
                )
                .disabled(isReadOnly)

                TextField("—", text: text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
                    .frame(minWidth: width, maxWidth: .infinity)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isReadOnly)
                    .accessibilityLabel(accessibilityFieldLabel)
                    .accessibilityHint(targetHint ?? "")
                    .accessibilityIdentifier("\(idBase).Field")

                StepIconButton(
                    systemName: "plus.circle",
                    action: plus,
                    accessibilityLabel: plusAccessibilityLabel,
                    accessibilityID: "\(idBase).Plus",
                    visualSize: compactControlVisualSize
                )
                .disabled(isReadOnly)

                if let trailing { trailing }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct WeightedEditorRowLayout: Layout {
        let weights: [CGFloat]
        let spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let measuredWidth = proposal.width ?? subviews.reduce(0) { partial, subview in
                partial + subview.sizeThatFits(.unspecified).width
            } + spacing * CGFloat(max(0, subviews.count - 1))
            let widths = allocatedWidths(totalWidth: measuredWidth, count: subviews.count)
            var maxHeight: CGFloat = 0
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(ProposedViewSize(width: widths[index], height: proposal.height))
                maxHeight = max(maxHeight, size.height)
            }
            return CGSize(width: measuredWidth, height: maxHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let widths = allocatedWidths(totalWidth: bounds.width, count: subviews.count)
            var x = bounds.minX
            for (index, subview) in subviews.enumerated() {
                let width = widths[index]
                subview.place(
                    at: CGPoint(x: x, y: bounds.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: proposal.height)
                )
                x += width + spacing
            }
        }

        private func allocatedWidths(totalWidth: CGFloat, count: Int) -> [CGFloat] {
            guard count > 0 else { return [] }
            let totalSpacing = spacing * CGFloat(max(0, count - 1))
            let availableWidth = max(0, totalWidth - totalSpacing)
            let normalizedWeights = weights.count == count && weights.reduce(0, +) > 0
                ? weights
                : Array(repeating: 1, count: count)
            let totalWeight = normalizedWeights.reduce(0, +)
            guard totalWeight > 0 else {
                return Array(repeating: availableWidth / CGFloat(count), count: count)
            }
            return normalizedWeights.map { availableWidth * ($0 / totalWeight) }
        }
    }

    private struct PersistedRowState: Equatable {
        let reps: Int?
        let weight: Double?
        let weightUnitRaw: String
        let completed: Bool
        let completedAt: Date?
    }

    private struct StepIconButton: View {
        let systemName: String
        let action: () -> Void
        let accessibilityLabel: String
        let accessibilityID: String
        let visualSize: CGFloat

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(visualSize <= 32 ? .body : .title3)
                    .foregroundStyle(.secondary)
                    .frame(width: visualSize, height: visualSize)
                    .contentShape(Rectangle())
                    .accessibilityDecorative()
            }
            .buttonStyle(.plain)
            .accessibilityIconControl(label: accessibilityLabel, identifier: accessibilityID)
        }
    }

    private func formatWeight(_ w: Double) -> String {
        if w.rounded() == w { return String(Int(w)) }
        return String(format: "%.1f", w)
    }

    private func formatRPE(_ r: Double) -> String {
        if r.rounded() == r { return String(Int(r)) }
        return String(format: "%.1f", r)
    }

    private func fireCompletionHaptic() {
    #if canImport(UIKit)
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    #endif
    }
}
