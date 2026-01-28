import Foundation

/// Pure heuristics for "Coach mode".
/// - No SwiftData
/// - No UI
/// - Just decisions based on values
struct CoachSuggestionService {

    // MARK: - Prompt (nudge after set)

    struct Prompt: Hashable {
        let title: String
        let message: String

        let suggestedRestSeconds: Int

        let weightDelta: Double?
        let repsDelta: Int?

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

        let rest = suggestRestSeconds(
            rpe: rpe,
            plannedRestSeconds: plannedRestSeconds,
            defaultRestSeconds: defaultRestSeconds
        )

        let isLb = weightUnitRaw.lowercased() == "lb"
        let weightStep: Double = isLb ? 5.0 : 2.5

        let hasWeight = (completedWeight ?? 0) > 0
        let hasReps = (completedReps ?? 0) > 0

        var wDelta: Double? = nil
        var rDelta: Int? = nil

        // Opinionated nudge:
        // easy -> add weight, medium -> add rep, hard -> just rest.
        if let rpe {
            if rpe <= 7.5 {
                if hasWeight { wDelta = weightStep }
                else if hasReps { rDelta = 1 }
            } else if rpe <= 8.7 {
                if hasReps { rDelta = 1 }
                else if hasWeight { wDelta = weightStep }
            } else {
                // no push suggestion
            }
        } else {
            // No RPE: gentle nudge
            if hasReps { rDelta = 1 }
            else if hasWeight { wDelta = weightStep }
        }

        let weightLabel = wDelta.map { d in "+\(format(d)) \(weightUnitRaw)" }
        let repsLabel = rDelta.map { d in "+\(d) rep" }

        let msg: String = {
            if let rpe { return "RPE \(format(rpe)) → suggested rest ~\(rest)s." }
            return "Suggested rest ~\(rest)s."
        }()

        return Prompt(
            title: "Coach",
            message: msg,
            suggestedRestSeconds: rest,
            weightDelta: wDelta,
            repsDelta: rDelta,
            weightLabel: weightLabel,
            repsLabel: repsLabel
        )
    }

    func suggestRestSeconds(rpe: Double?, plannedRestSeconds: Int?, defaultRestSeconds: Int) -> Int {
        let base = plannedRestSeconds ?? defaultRestSeconds
        guard let rpe else { return base }

        if rpe <= 6.5 { return max(45, Int(Double(base) * 0.9)) }
        if rpe <= 7.5 { return base }
        if rpe <= 8.5 { return max(base, 120) }
        if rpe <= 9.2 { return max(base, 150) }
        return max(base, 180)
    }

    // MARK: - PR detection (celebration)

    struct CompletedSet: Hashable {
        let weight: Double?
        let reps: Int?
        let weightUnitRaw: String
        let rpe: Double?
    }

    enum PRKind: String, Hashable {
        case bestWeight = "Best weight"
        case bestReps = "Best reps"
        case bestVolume = "Best volume"
        case bestE1RM = "Best est. 1RM"
    }

    struct PRAchievement: Hashable {
        let kind: PRKind
        let valueText: String
    }

    /// Returns PR achievements if `completed` strictly beats *previous* history.
    func prAchievements(completed: CompletedSet, previous: [CompletedSet]) -> [PRAchievement] {
        let prevMaxWeight = previous.compactMap(\.weight).max() ?? 0
        let prevMaxReps = previous.compactMap(\.reps).max() ?? 0
        let prevMaxVolume = previous.map(volume).max() ?? 0
        let prevMaxE1RM = previous.map(e1rm).max() ?? 0

        var out: [PRAchievement] = []

        let w = completed.weight ?? 0
        let r = completed.reps ?? 0
        let v = volume(completed)
        let e = e1rm(completed)

        if w > prevMaxWeight, w > 0 {
            out.append(.init(kind: .bestWeight, valueText: "\(format(w)) \(completed.weightUnitRaw)"))
        }
        if r > prevMaxReps, r > 0 {
            out.append(.init(kind: .bestReps, valueText: "\(r)"))
        }
        if v > prevMaxVolume, v > 0 {
            out.append(.init(kind: .bestVolume, valueText: "\(format(v))"))
        }
        if e > prevMaxE1RM, e > 0 {
            out.append(.init(kind: .bestE1RM, valueText: "\(format(e)) \(completed.weightUnitRaw)"))
        }

        return out
    }

    private func volume(_ s: CompletedSet) -> Double {
        let w = s.weight ?? 0
        let r = Double(s.reps ?? 0)
        return w * r
    }

    // Epley: w * (1 + reps/30)
    private func e1rm(_ s: CompletedSet) -> Double {
        let w = s.weight ?? 0
        let r = Double(s.reps ?? 0)
        guard w > 0, r > 0 else { return 0 }
        return w * (1.0 + r / 30.0)
    }

    private func format(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }
}
