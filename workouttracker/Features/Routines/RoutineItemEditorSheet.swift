import SwiftUI
import SwiftData

struct RoutineItemEditorScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: WorkoutRoutineItem

    var body: some View {
        List {
            Section("Exercise") {
                Text(item.exercise?.name ?? "Unknown")
                    .font(.headline)

                TextField("Notes", text: Binding(
                    get: { item.notes ?? "" },
                    set: { item.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...6)
            }
            Section("Insights") {
                if let ex = item.exercise {
                    ExerciseInsightsSectionView(
                        exerciseId: ex.id,
                        exerciseName: ex.name
                    )
                } else {
                    ContentUnavailableView(
                        "No exercise selected",
                        systemImage: "dumbbell",
                        description: Text("Pick an exercise to see PRs, trends, and history.")
                    )
                    .listRowSeparator(.hidden)
                }
            }
            Section("Set plans") {
                if setPlansSorted.isEmpty {
                    ContentUnavailableView(
                        "No sets",
                        systemImage: "plus.circle",
                        description: Text("Add planned sets for this exercise.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(setPlansSorted) { plan in
                        SetPlanRow(plan: plan)
                    }
                    .onMove(perform: movePlans)
                    .onDelete(perform: deletePlans)
                }

                Button { addPlan() } label: {
                    Label("Add set", systemImage: "plus")
                }
            }
        }
        .navigationTitle(item.exercise?.name ?? "Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .onChange(of: item.setPlans.count) { _, _ in
            // keep orders tidy when things change
            normalizePlanOrders()
        }
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
}

private struct SetPlanRow: View {
    @Bindable var plan: WorkoutSetPlan

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
