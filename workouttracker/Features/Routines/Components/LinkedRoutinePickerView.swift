import SwiftUI

// File: workouttracker/Features/Routines/Components/LinkedRoutinePickerView.swift
//
// Why this file lives here:
// This is routine-authoring UI. It stays intentionally dumb: the view presents
// the current link, allows choose/change/clear, and excludes the main routine
// itself from the picker list. Relationship validation still lives in
// RoutineLinkPlanner.

struct LinkedRoutinePickerView: View {
    enum Role {
        case warmUp
        case coolDown

        var title: LocalizedStringKey {
            switch self {
            case .warmUp: "Warm-up"
            case .coolDown: "Cool-down"
            }
        }

        var pickerTitle: String {
            switch self {
            case .warmUp: "Pick Warm-Up"
            case .coolDown: "Pick Cool-Down"
            }
        }

        var emptyValue: LocalizedStringKey {
            switch self {
            case .warmUp: "No warm-up linked"
            case .coolDown: "No cool-down linked"
            }
        }

        var helperText: LocalizedStringKey {
            switch self {
            case .warmUp: "Choose a reusable routine that should run before the main work."
            case .coolDown: "Choose a reusable routine that should run after the main work."
            }
        }

        var clearLabel: LocalizedStringKey {
            switch self {
            case .warmUp: "Remove warm-up link"
            case .coolDown: "Remove cool-down link"
            }
        }
    }

    let role: Role
    let mainRoutineID: UUID
    let currentRoutine: WorkoutRoutine?
    let onSelect: (WorkoutRoutine) -> Void
    let onClear: () -> Void

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(role.title)
                            .font(.subheadline.weight(.semibold))

                        currentRoutineNameView
                            .font(.subheadline)
                            .foregroundStyle(currentRoutine == nil ? .secondary : .primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(currentRoutine == nil ? "Choose" : "Change")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if currentRoutine != nil {
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label(role.clearLabel, systemImage: "xmark.circle")
                }
                .buttonStyle(.plain)
            }

            Text(role.helperText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showPicker) {
            RoutinePickerSheet(
                title: role.pickerTitle,
                selectedRoutineId: currentRoutine?.id,
                excludedRoutineIDs: [mainRoutineID],
                onPick: { picked in
                    if let picked {
                        onSelect(picked)
                    } else {
                        onClear()
                    }
                    showPicker = false
                }
            )
        }
    }

    @ViewBuilder
    private var currentRoutineNameView: some View {
        if let currentRoutine {
            Text(currentRoutine.name)
        } else {
            Text(role.emptyValue)
        }
    }
}
