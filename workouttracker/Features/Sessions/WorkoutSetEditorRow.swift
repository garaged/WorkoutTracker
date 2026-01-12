import SwiftUI
import SwiftData

/// Fast inline editing for reps/weight + done toggle.
/// Aligned to `WorkoutSetLog` (completed/targetRestSeconds/weightUnit).
struct WorkoutSetEditorRow: View {
    @Bindable var set: WorkoutSetLog

    let setNumber: Int
    let isReadOnly: Bool
    var onCompleted: ((Int?) -> Void)? = nil   // rest seconds

    private var repsBinding: Binding<String> {
        Binding<String>(
            get: { set.reps.map(String.init) ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                set.reps = Int(trimmed)
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
                if trimmed.isEmpty { set.weight = nil; return }
                let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                set.weight = Double(normalized)
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
        HStack(spacing: 12) {
            Text("\(setNumber)")
                .font(.headline)
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(set.completed ? .secondary : .primary)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    LabeledContent("Reps") {
                        TextField("—", text: repsBinding)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 64)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isReadOnly)
                    }

                    LabeledContent("Weight") {
                        HStack(spacing: 6) {
                            TextField("—", text: weightBinding)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 88)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isReadOnly)

                            Text(set.weightUnit.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let hint = targetHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                let wasCompleted = set.completed
                set.completed.toggle()
                set.completedAt = set.completed ? Date() : nil

                if !wasCompleted && set.completed {
                    onCompleted?(set.targetRestSeconds)
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(isReadOnly)
            .accessibilityLabel(set.completed ? "Mark set not completed" : "Mark set completed")
        }
        .padding(.vertical, 6)
    }

    private func formatWeight(_ w: Double) -> String {
        if w.rounded() == w { return String(Int(w)) }
        return String(w)
    }

    private func formatRPE(_ r: Double) -> String {
        if r.rounded() == r { return String(Int(r)) }
        return String(r)
    }
}
