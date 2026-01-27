import Foundation

/// Small, opinionated heuristics for "what should I do next?" while training.
/// Keep it pure: no SwiftData, no UI, just decisions.
struct CoachSuggestionService {

    struct Prompt: Hashable {
        /// e.g. "Nice. Want to push the next set?"
        let title: String

        /// e.g. "Based on RPE 8.0, rest ~150s."
        let message: String

        /// Suggested rest to start after completing this set.
        let suggestedRestSeconds: Int

        /// Suggestion for the next set
        let weightDelta: Double?
        let repsDelta: Int?

        /// Preformatted button labels
        let weightLabel: String?
        let repsLabel: String?
    }

    func makePrompt(
        completedWeight: Double?,
        completedReps: Int?,
        weightUnitRaw: String,
        rpe: Double?,
        plannedRestSeconds: Int?,
        defaultRestSeconds: Int = 90
    ) -> Prompt {

        let rest = suggestRestSeconds(rpe: rpe, plannedRestSeconds: plannedRestSeconds, defaultRestSeconds: defaultRestSeconds)

        // Opinionated increments:
        // - kg: +2.5
        // - lb: +5
        let isLb = weightUnitRaw.lowercased() == "lb"
        let weightStep: Double = isLb ? 5.0 : 2.5

        // Determine if weight-based suggestion makes sense
        let hasWeight = (completedWeight ?? 0) > 0
        let hasReps = (completedReps ?? 0) > 0

        // Nudge policy:
        // - If RPE is low (<=7.5), suggest weight
        // - If RPE is medium (7.6–8.7), suggest +1 rep
        // - If RPE is high (>=8.8), suggest only rest (light nudge)
        var wDelta: Double? = nil
        var rDelta: Int? = nil

        if let rpe {
            if rpe <= 7.5 {
                if hasWeight { wDelta = weightStep }
                else if hasReps { rDelta = 1 }
            } else if rpe <= 8.7 {
                if hasReps { rDelta = 1 }
                else if hasWeight { wDelta = weightStep }
            } else {
                // Hard set — no push suggestion, only rest suggestion.
            }
        } else {
            // If no RPE: be gentle and suggest reps if possible, else weight.
            if hasReps { rDelta = 1 }
            else if hasWeight { wDelta = weightStep }
        }

        let weightLabel = wDelta.map { delta in
            let sym = delta >= 0 ? "+" : ""
            return "\(sym)\(format(delta)) \(weightUnitRaw)"
        }

        let repsLabel = rDelta.map { delta in
            let sym = delta >= 0 ? "+" : ""
            return "\(sym)\(delta) rep"
        }

        let title = "Coach"
        let msg = {
            if let rpe {
                return "RPE \(format(rpe)) → suggested rest ~\(rest)s."
            } else {
                return "Suggested rest ~\(rest)s."
            }
        }()

        return Prompt(
            title: title,
            message: msg,
            suggestedRestSeconds: rest,
            weightDelta: wDelta,
            repsDelta: rDelta,
            weightLabel: weightLabel,
            repsLabel: repsLabel
        )
    }

    func suggestRestSeconds(rpe: Double?, plannedRestSeconds: Int?, defaultRestSeconds: Int) -> Int {
        // If the plan has rest, use it as baseline.
        let base = plannedRestSeconds ?? defaultRestSeconds

        guard let rpe else { return base }

        // Simple, predictable mapping:
        // easy -> a bit less, moderate -> baseline+, hard -> more.
        if rpe <= 6.5 { return max(45, Int(Double(base) * 0.9)) }
        if rpe <= 7.5 { return base }
        if rpe <= 8.5 { return max(base, 120) }
        if rpe <= 9.2 { return max(base, 150) }
        return max(base, 180)
    }

    private func format(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }
}
