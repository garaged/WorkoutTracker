import Foundation

public enum ProgressionRule: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Hashable, Sendable {
        case fixedLoadIncrease
        case doubleProgression
        case deloadEvery
        case repeatWeekOnFailureThreshold
    }

    case fixedLoadIncrease(step: Double)
    case doubleProgression(minReps: Int, maxReps: Int, loadStep: Double)
    case deloadEvery(weeks: Int, percent: Double)
    case repeatWeekOnFailureThreshold(failedSets: Int)

    public var kind: Kind {
        switch self {
        case .fixedLoadIncrease:
            return .fixedLoadIncrease
        case .doubleProgression:
            return .doubleProgression
        case .deloadEvery:
            return .deloadEvery
        case .repeatWeekOnFailureThreshold:
            return .repeatWeekOnFailureThreshold
        }
    }

    public var isValid: Bool {
        switch self {
        case .fixedLoadIncrease(let step):
            return step > 0
        case .doubleProgression(let minReps, let maxReps, let loadStep):
            return minReps > 0 && maxReps >= minReps && loadStep > 0
        case .deloadEvery(let weeks, let percent):
            return weeks > 0 && percent > 0 && percent < 1
        case .repeatWeekOnFailureThreshold(let failedSets):
            return failedSets > 0
        }
    }
}

extension ProgressionRule {
    private enum CodingKeys: String, CodingKey {
        case kind
        case step
        case minReps
        case maxReps
        case loadStep
        case weeks
        case percent
        case failedSets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .fixedLoadIncrease:
            let step = try container.decode(Double.self, forKey: .step)
            self = .fixedLoadIncrease(step: step)
        case .doubleProgression:
            let minReps = try container.decode(Int.self, forKey: .minReps)
            let maxReps = try container.decode(Int.self, forKey: .maxReps)
            let loadStep = try container.decode(Double.self, forKey: .loadStep)
            self = .doubleProgression(minReps: minReps, maxReps: maxReps, loadStep: loadStep)
        case .deloadEvery:
            let weeks = try container.decode(Int.self, forKey: .weeks)
            let percent = try container.decode(Double.self, forKey: .percent)
            self = .deloadEvery(weeks: weeks, percent: percent)
        case .repeatWeekOnFailureThreshold:
            let failedSets = try container.decode(Int.self, forKey: .failedSets)
            self = .repeatWeekOnFailureThreshold(failedSets: failedSets)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)

        switch self {
        case .fixedLoadIncrease(let step):
            try container.encode(step, forKey: .step)
        case .doubleProgression(let minReps, let maxReps, let loadStep):
            try container.encode(minReps, forKey: .minReps)
            try container.encode(maxReps, forKey: .maxReps)
            try container.encode(loadStep, forKey: .loadStep)
        case .deloadEvery(let weeks, let percent):
            try container.encode(weeks, forKey: .weeks)
            try container.encode(percent, forKey: .percent)
        case .repeatWeekOnFailureThreshold(let failedSets):
            try container.encode(failedSets, forKey: .failedSets)
        }
    }
}
