import SwiftUI

// File: workouttracker/Features/Routines/StarterBadge.swift
//
// A tiny, subtle badge for built-in content (e.g. "Starter").
// Keeps the UI looking polished without shouting.

struct StarterBadge: View {
    let text: String

    init(text: String = "Starter") {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
            )
            .foregroundStyle(.secondary)
    }
}
