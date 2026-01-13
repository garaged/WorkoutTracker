import SwiftUI

struct WorkoutSetPlanEditorRow: View {
    @Bindable var plan: WorkoutSetPlan
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Set \(plan.order + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(weightLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Stepper("Reps", value: repsBinding, in: 0...60)
                    .labelsHidden()
                Text(repsLabel).font(.caption)

                Stepper("Weight", value: weightBinding, in: 0...500, step: 2.5)
                    .labelsHidden()
                Text("kg").font(.caption).foregroundStyle(.secondary)

                Spacer()

                Stepper("Rest", value: restBinding, in: 0...600, step: 15)
                    .labelsHidden()
                Text(restLabel).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var repsBinding: Binding<Int> {
        Binding(
            get: { plan.targetReps ?? 0 },
            set: { plan.targetReps = ($0 == 0 ? nil : $0); onChanged() }
        )
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { plan.targetWeight ?? 0 },
            set: { plan.targetWeight = ($0 == 0 ? nil : $0); onChanged() }
        )
    }

    private var restBinding: Binding<Int> {
        Binding(
            get: { plan.restSeconds ?? 0 },
            set: { plan.restSeconds = ($0 == 0 ? nil : $0); onChanged() }
        )
    }

    private var repsLabel: String {
        let r = plan.targetReps ?? 0
        return r == 0 ? "— reps" : "\(r) reps"
    }

    private var restLabel: String {
        let s = plan.restSeconds ?? 0
        return s == 0 ? "—" : "\(s)s"
    }

    private var weightLabel: String {
        guard let w = plan.targetWeight, w > 0 else { return "—" }
        return String(format: "%.1f %@", w, plan.weightUnitRaw)
    }
}
