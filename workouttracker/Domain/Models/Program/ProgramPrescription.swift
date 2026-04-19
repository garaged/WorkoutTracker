import Foundation

public struct ProgramPrescription: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var order: Int
    public var exerciseId: UUID?
    public var exerciseKey: String?
    public var exerciseNameSnapshot: String?
    public var targetSets: Int?
    public var targetReps: Int?
    public var targetWeight: Double?
    public var weightUnit: WeightUnit?
    public var targetDurationSeconds: Int?
    public var targetDistance: Double?
    public var distanceUnit: DistanceUnit?
    public var targetRPE: Double?
    public var progressionRules: [ProgressionRule]
    public var notes: String?

    public init(
        id: UUID = UUID(),
        order: Int,
        exerciseId: UUID? = nil,
        exerciseKey: String? = nil,
        exerciseNameSnapshot: String? = nil,
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        weightUnit: WeightUnit? = nil,
        targetDurationSeconds: Int? = nil,
        targetDistance: Double? = nil,
        distanceUnit: DistanceUnit? = nil,
        targetRPE: Double? = nil,
        progressionRules: [ProgressionRule] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.order = order
        self.exerciseId = exerciseId
        self.exerciseKey = exerciseKey
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.weightUnit = weightUnit
        self.targetDurationSeconds = targetDurationSeconds
        self.targetDistance = targetDistance
        self.distanceUnit = distanceUnit
        self.targetRPE = targetRPE
        self.progressionRules = progressionRules
        self.notes = notes
    }
}

extension ProgramPrescription {
    public var hasProgressionRules: Bool {
        !progressionRules.isEmpty
    }
}

extension ProgramPrescription {
    private enum CodingKeys: String, CodingKey {
        case id
        case order
        case exerciseId
        case exerciseKey
        case exerciseNameSnapshot
        case targetSets
        case targetReps
        case targetWeight
        case weightUnit
        case targetDurationSeconds
        case targetDistance
        case distanceUnit
        case targetRPE
        case progressionRules
        case notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.order = (try? c.decode(Int.self, forKey: .order)) ?? 1
        self.exerciseId = try? c.decode(UUID.self, forKey: .exerciseId)
        self.exerciseKey = try? c.decode(String.self, forKey: .exerciseKey)
        self.exerciseNameSnapshot = try? c.decode(String.self, forKey: .exerciseNameSnapshot)
        self.targetSets = try? c.decode(Int.self, forKey: .targetSets)
        self.targetReps = try? c.decode(Int.self, forKey: .targetReps)
        self.targetWeight = try? c.decode(Double.self, forKey: .targetWeight)
        self.weightUnit = try? c.decode(WeightUnit.self, forKey: .weightUnit)
        self.targetDurationSeconds = try? c.decode(Int.self, forKey: .targetDurationSeconds)
        self.targetDistance = try? c.decode(Double.self, forKey: .targetDistance)
        self.distanceUnit = try? c.decode(DistanceUnit.self, forKey: .distanceUnit)
        self.targetRPE = try? c.decode(Double.self, forKey: .targetRPE)
        self.progressionRules = (try? c.decode([ProgressionRule].self, forKey: .progressionRules)) ?? []
        self.notes = try? c.decode(String.self, forKey: .notes)
    }
}
