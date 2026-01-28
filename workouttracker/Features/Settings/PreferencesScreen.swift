import SwiftUI

// File: workouttracker/Features/Settings/PreferencesScreen.swift
struct PreferencesScreen: View {
    @AppStorage(UnitPreferences.Keys.weightUnitRaw)
    private var weightUnitRaw: String = WeightUnit.kg.rawValue

    private var weightUnitBinding: Binding<WeightUnit> {
        Binding(
            get: { WeightUnit(rawValue: weightUnitRaw) ?? .kg },
            set: { newUnit in
                weightUnitRaw = newUnit.rawValue
            }
        )
    }

    var body: some View {
        List {
            Section("Units") {
                Picker("Weight", selection: weightUnitBinding) {
                    ForEach(WeightUnit.allCases, id: \.self) { u in
                        Text(u.label.uppercased()).tag(u)
                    }
                }
                .pickerStyle(.segmented) // feels nice for 2 options; swap to .menu if you prefer
            }

            Section {
                Text("This affects display and new entries across the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
