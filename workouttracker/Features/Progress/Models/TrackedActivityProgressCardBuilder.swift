import Foundation

// File: workouttracker/Features/Progress/Models/TrackedActivityProgressCardBuilder.swift
//
// Why this file lives here:
// This builder shapes tracked-activity session data into the Progress dashboard's
// card model, so it stays close to the feature that owns the presentation.

struct TrackedActivityProgressCardBuilder {
    func build(from sessions: [TrackedActivitySession]) -> TrackedActivitySummaryCardModel? {
        let summaries = sessions
            .map(\.summary)
            .filter { $0.lifecycleState == .completed || $0.lifecycleState == .discarded }

        return TrackedActivitySummaryCardModel.build(from: summaries)
    }

    func signature(for sessions: [TrackedActivitySession]) -> [String] {
        sessions.map { session in
            [
                session.id.uuidString,
                session.lifecycleStateRaw,
                String(session.updatedAt.timeIntervalSinceReferenceDate),
                String(session.routePointCount)
            ].joined(separator: "|")
        }
    }
}
