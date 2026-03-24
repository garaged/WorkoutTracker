import Foundation

enum SessionAttentionState: Equatable {
    case fresh
    case staleSuppressed
    case staleNeedsPrompt
}

struct SessionAttentionEvaluation: Equatable {
    let state: SessionAttentionState
    let isStale: Bool
    let shouldShowRecoveryPrompt: Bool
}

struct SessionAttentionEvaluator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func evaluate(
        session: WorkoutSession,
        owningDay: Date,
        now: Date = Date()
    ) -> SessionAttentionEvaluation {
        guard session.status == .inProgress, session.endedAt == nil else {
            return .init(state: .fresh, isStale: false, shouldShowRecoveryPrompt: false)
        }

        let isStale = calendar.startOfDay(for: owningDay) < calendar.startOfDay(for: now)
        guard isStale else {
            return .init(state: .fresh, isStale: false, shouldShowRecoveryPrompt: false)
        }

        if let dismissed = session.dismissedStalePromptAt,
           calendar.isDate(dismissed, inSameDayAs: now) {
            return .init(state: .staleSuppressed, isStale: true, shouldShowRecoveryPrompt: false)
        }

        return .init(state: .staleNeedsPrompt, isStale: true, shouldShowRecoveryPrompt: true)
    }
}
