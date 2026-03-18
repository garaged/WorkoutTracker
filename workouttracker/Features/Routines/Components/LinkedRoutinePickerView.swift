import SwiftUI

// File: workouttracker/Features/Routines/Components/LinkedRoutinePickerView.swift
//
// Why this file lives here:
// This component is the reusable picker row for warm-up / cool-down routine links.
// It belongs with routine UI because it renders routine-specific selection state.

struct LinkedRoutinePickerView: View {
    enum Role {
        case warmUp
        case coolDown

        var title: LocalizedStringKey {
            switch self {
            case .warmUp: "routine.link.warm_up.title"
            case .coolDown: "routine.link.cool_down.title"
            }
        }

        var pickerTitle: String {
            switch self {
            case .warmUp: String(localized: "routine.link.warm_up.picker_title")
            case .coolDown: String(localized: "routine.link.cool_down.picker_title")
            }
        }

        var emptyValue: LocalizedStringKey {
            switch self {
            case .warmUp: "routine.link.warm_up.empty"
            case .coolDown: "routine.link.cool_down.empty"
            }
        }

        var helperText: LocalizedStringKey {
            switch self {
            case .warmUp: "routine.link.warm_up.helper"
            case .coolDown: "routine.link.cool_down.helper"
            }
        }

        var clearLabel: LocalizedStringKey {
            switch self {
            case .warmUp: "routine.link.warm_up.clear"
            case .coolDown: "routine.link.cool_down.clear"
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

                    Text(currentRoutine == nil ? String(localized: "common.choose") : String(localized: "common.change"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(role.title)
            .accessibilityValue(currentRoutine?.name ?? emptyAccessibilityValue)

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

    private var emptyAccessibilityValue: String {
        switch role {
        case .warmUp:
            return String(localized: "routine.link.warm_up.empty")
        case .coolDown:
            return String(localized: "routine.link.cool_down.empty")
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
