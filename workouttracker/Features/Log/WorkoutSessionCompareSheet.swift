import SwiftUI

// File: workouttracker/Features/Log/WorkoutSessionCompareSheet.swift
struct WorkoutSessionCompareSheet: View {
    let a: WorkoutSession
    let b: WorkoutSession

    @Environment(\.dismiss) private var dismiss

    /// Single source of truth for display + calculation.
    private var preferredUnit: WeightUnit { UnitPreferences.weightUnit }

    var body: some View {
        let sa = WorkoutSessionCompareService.stats(for: a, preferredUnit: preferredUnit)
        let sb = WorkoutSessionCompareService.stats(for: b, preferredUnit: preferredUnit)

        NavigationStack {
            List {
                Section("Sessions") {
                    sessionHeader("A", session: a)
                    sessionHeader("B", session: b)
                }

                Section("Totals") {
                    metricRow("Duration",
                              a: sa.durationText ?? "—",
                              b: sb.durationText ?? "—",
                              delta: deltaSeconds(sb.durationSeconds - sa.durationSeconds))

                    metricRow("Exercises",
                              a: "\(sa.exerciseCount)",
                              b: "\(sb.exerciseCount)",
                              delta: deltaInt(sb.exerciseCount - sa.exerciseCount))

                    metricRow("Completed sets",
                              a: "\(sa.completedSets)",
                              b: "\(sb.completedSets)",
                              delta: deltaInt(sb.completedSets - sa.completedSets))

                    metricRow("Volume (\(preferredUnit.label))",
                              a: fmt0(sa.volume),
                              b: fmt0(sb.volume),
                              delta: deltaDouble(sb.volume - sa.volume))

                    Text("Volume uses your preferred unit (\(preferredUnit.label)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Best set") {
                    Text("A: \(sa.bestSetText ?? "—")")
                        .foregroundStyle(.secondary)
                    Text("B: \(sb.bestSetText ?? "—")")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - UI helpers

    private func sessionHeader(_ tag: String, session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(tag): \(session.sourceRoutineNameSnapshot ?? "Quick Workout")")
                .font(.headline)
                .lineLimit(1)

            Text(session.startedAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func metricRow(_ title: String, a: String, b: String, delta: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("A").font(.caption2).foregroundStyle(.secondary)
                    Text(a).font(.subheadline.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("B").font(.caption2).foregroundStyle(.secondary)
                    Text(b).font(.subheadline.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Δ").font(.caption2).foregroundStyle(.secondary)
                    Text(delta ?? "—")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(delta == nil ? .secondary : .primary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Formatting

    private func fmt0(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0)))
    }

    private func deltaInt(_ d: Int) -> String {
        d == 0 ? "±0" : (d > 0 ? "+\(d)" : "\(d)")
    }

    private func deltaDouble(_ d: Double) -> String {
        let v = Int(d.rounded())
        return v == 0 ? "±0" : (v > 0 ? "+\(v)" : "\(v)")
    }

    private func deltaSeconds(_ d: Int) -> String {
        let mins = abs(d) / 60
        if mins == 0 { return "±0m" }
        return d > 0 ? "+\(mins)m" : "−\(mins)m"
    }
}
