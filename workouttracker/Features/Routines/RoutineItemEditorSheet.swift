import SwiftUI
import SwiftData

struct RoutineItemEditorScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: WorkoutRoutineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Set \(plan.order + 1)")
                    .font(.headline)
                Spacer()
            }

            if style.showsReps || style.showsWeight {
                HStack(spacing: 10) {
                    if style.showsReps {
                        LabeledContent("Reps") {
                            TextField("—", text: repsBinding)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 70)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    if style.showsWeight {
                        LabeledContent("Weight") {
                            HStack(spacing: 6) {
                                TextField("—", text: weightBinding)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 90)
                                    .textFieldStyle(.roundedBorder)

                                Picker("", selection: Binding(
                                    get: { plan.weightUnit },
                                    set: { plan.weightUnit = $0 }
                                )) {
                                    ForEach(WeightUnit.allCases, id: \.self) { u in
                                        Text(u.rawValue).tag(u)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
            }

            if style.showsDuration || style.showsDistance {
                HStack(spacing: 10) {
                    if style.showsDuration {
                        LabeledContent("Duration (min)") {
                            TextField("—", text: durationMinutesBinding)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    if style.showsDistance {
                        LabeledContent("Distance") {
                            TextField("—", text: distanceBinding)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            if style.showsRPE || style.showsRest {
                HStack(spacing: 10) {
                    if style.showsRPE {
                        LabeledContent("RPE") {
                            TextField("—", text: rpeBinding)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    if style.showsRest {
                        LabeledContent("Rest") {
                            Stepper(value: Binding(
                                get: { plan.restSeconds ?? 90 },
                                set: { plan.restSeconds = $0 }
                            ), in: 0...600, step: 15) {
                                Text("\(plan.restSeconds ?? 90)s")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private var durationMinutesBinding: Binding<String> {
        Binding(
            get: {
                guard let s = plan.targetDurationSeconds else { return "" }
                let mins = Double(s) / 60.0
                return mins.rounded() == mins ? String(Int(mins)) : String(mins)
            },
            set: {
                let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { plan.targetDurationSeconds = nil; return }
                let v = Double(t.replacingOccurrences(of: ",", with: ".")) ?? 0
                plan.targetDurationSeconds = Int((v * 60.0).rounded())
            }
        )
    }

    private var distanceBinding: Binding<String> {
        Binding(
            get: {
                guard let d = plan.targetDistance else { return "" }
                return d.rounded() == d ? String(Int(d)) : String(d)
            },
            set: {
                let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { plan.targetDistance = nil; return }
                plan.targetDistance = Double(t.replacingOccurrences(of: ",", with: "."))
            }
        )
    }

    private var setPlansSorted: [WorkoutSetPlan] {
        item.setPlans.sorted { $0.order < $1.order }
    }

    private func addPlan() {
        let nextOrder = (item.setPlans.map(\.order).max() ?? -1) + 1
        let last = setPlansSorted.last

        let p = WorkoutSetPlan(
            order: nextOrder,
            targetReps: last?.targetReps,
            targetWeight: last?.targetWeight,
            weightUnit: last?.weightUnit ?? .kg,
            targetRPE: last?.targetRPE,
            restSeconds: last?.restSeconds ?? 90,
            routineItem: item
        )

        item.setPlans.append(p)
        normalizePlanOrders()
        try? modelContext.save()
    }

    private func movePlans(from: IndexSet, to: Int) {
        var sorted = setPlansSorted
        sorted.move(fromOffsets: from, toOffset: to)
        for (idx, p) in sorted.enumerated() { p.order = idx }
        try? modelContext.save()
    }

    private func deletePlans(_ indexSet: IndexSet) {
        let sorted = setPlansSorted
        for i in indexSet {
            modelContext.delete(sorted[i])
        }
        normalizePlanOrders()
        try? modelContext.save()
    }

    private func normalizePlanOrders() {
        let sorted = setPlansSorted
        for (idx, p) in sorted.enumerated() { p.order = idx }
    }
    private func applyStyleToPlans(_ style: ExerciseTrackingStyle) {
        if style == .notesOnly {
            for p in item.setPlans.sorted(by: { $0.order < $1.order }) { modelContext.delete(p) }
            item.setPlans.removeAll()
            try? modelContext.save()
            return
        }

        // Ensure at least 1 plan for styles that use rows
        if item.setPlans.isEmpty {
            addPlan()
        }

        // Scrub fields that don’t apply
        for p in item.setPlans {
            if !style.showsReps { p.targetReps = nil }
            if !style.showsWeight { p.targetWeight = nil }
            if !style.showsRPE { p.targetRPE = nil }
            if !style.showsDuration { p.targetDurationSeconds = nil }
            if !style.showsDistance { p.targetDistance = nil }
        }

        normalizePlanOrders()
        try? modelContext.save()
    }
}

private struct SetPlanRow: View {
    @Bindable var plan: WorkoutSetPlan
    let style: ExerciseTrackingStyle

    private var repsBinding: Binding<String> {
        Binding(
            get: { plan.targetReps.map(String.init) ?? "" },
            set: { plan.targetReps = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: {
                guard let w = plan.targetWeight else { return "" }
                return w.rounded() == w ? String(Int(w)) : String(w)
            },
            set: {
                let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { plan.targetWeight = nil; return }
                plan.targetWeight = Double(t.replacingOccurrences(of: ",", with: "."))
            }
        )
    }

    private var rpeBinding: Binding<String> {
        Binding(
            get: {
                guard let r = plan.targetRPE else { return "" }
                return r.rounded() == r ? String(Int(r)) : String(r)
            },
            set: {
                let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { plan.targetRPE = nil; return }
                plan.targetRPE = Double(t.replacingOccurrences(of: ",", with: "."))
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Set \(plan.order + 1)")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 10) {
                LabeledContent("Reps") {
                    TextField("—", text: repsBinding)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Weight") {
                    HStack(spacing: 6) {
                        TextField("—", text: weightBinding)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)

                        Picker("", selection: Binding(
                            get: { plan.weightUnit },
                            set: { plan.weightUnit = $0 }
                        )) {
                            ForEach(WeightUnit.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }

            HStack(spacing: 10) {
                LabeledContent("RPE") {
                    TextField("—", text: rpeBinding)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Rest") {
                    Stepper(value: Binding(
                        get: { plan.restSeconds ?? 90 },
                        set: { plan.restSeconds = $0 }
                    ), in: 0...600, step: 15) {
                        Text("\(plan.restSeconds ?? 90)s")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
