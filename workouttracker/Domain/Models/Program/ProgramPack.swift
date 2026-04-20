import Foundation

public struct ProgramPack: Codable, Hashable, Sendable {
    public static let supportedSchemaVersion = 2

    public var schemaVersion: Int
    public var packID: String
    public var generatedAt: Date?
    public var exercises: [ExerciseDTO]
    public var routines: [RoutineDTO]
    public var programs: [TrainingProgram]

    public init(
        schemaVersion: Int = ProgramPack.supportedSchemaVersion,
        packID: String? = nil,
        generatedAt: Date? = nil,
        exercises: [ExerciseDTO] = [],
        routines: [RoutineDTO] = [],
        programs: [TrainingProgram] = []
    ) {
        self.schemaVersion = schemaVersion
        self.packID = Self.normalizedPackID(packID, programs: programs)
        self.generatedAt = generatedAt
        self.exercises = exercises
        self.routines = routines
        self.programs = programs
    }

    public init(
        formatVersion: Int,
        packID: String? = nil,
        generatedAt: Date? = nil,
        exercises: [ExerciseDTO] = [],
        routines: [RoutineDTO] = [],
        programs: [TrainingProgram] = []
    ) {
        self.init(
            schemaVersion: formatVersion,
            packID: packID,
            generatedAt: generatedAt,
            exercises: exercises,
            routines: routines,
            programs: programs
        )
    }

    public var formatVersion: Int {
        get { schemaVersion }
        set { schemaVersion = newValue }
    }

    public var includesAssets: Bool {
        !exercises.isEmpty || !routines.isEmpty
    }

    private static func normalizedPackID(_ rawValue: String?, programs: [TrainingProgram]) -> String {
        if let rawValue {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return TrainingProgram.makeSlug(trimmed)
            }
        }

        if let firstProgram = programs.first {
            return "\(TrainingProgram.makeSlug(firstProgram.slug))-pack"
        }

        return "program-pack"
    }
}

public struct ExerciseDTO: Codable, Hashable, Sendable {
    public var slug: String
    public var name: String
    public var catalogKey: String?
    public var modality: String
    public var instructions: String?
    public var notes: String?
    public var equipmentTags: [String]?

    public init(
        slug: String,
        name: String,
        catalogKey: String? = nil,
        modality: String,
        instructions: String? = nil,
        notes: String? = nil,
        equipmentTags: [String]? = nil
    ) {
        self.slug = slug
        self.name = name
        self.catalogKey = catalogKey
        self.modality = modality
        self.instructions = instructions
        self.notes = notes
        self.equipmentTags = equipmentTags
    }
}

public struct RoutineDTO: Codable, Hashable, Sendable {
    public var slug: String
    public var name: String
    public var notes: String?
    public var items: [RoutineItemDTO]

    public init(slug: String, name: String, notes: String? = nil, items: [RoutineItemDTO]) {
        self.slug = slug
        self.name = name
        self.notes = notes
        self.items = items
    }
}

public struct RoutineItemDTO: Codable, Hashable, Sendable {
    public var order: Int
    public var exerciseSlug: String
    public var trackingStyle: String
    public var notes: String?
    public var setPlans: [SetPlanDTO]

    public init(
        order: Int,
        exerciseSlug: String,
        trackingStyle: String,
        notes: String? = nil,
        setPlans: [SetPlanDTO]
    ) {
        self.order = order
        self.exerciseSlug = exerciseSlug
        self.trackingStyle = trackingStyle
        self.notes = notes
        self.setPlans = setPlans
    }
}

public struct SetPlanDTO: Codable, Hashable, Sendable {
    public var order: Int
    public var targetReps: Int?
    public var targetWeight: Double?
    public var weightUnit: String?
    public var targetDurationSeconds: Int?
    public var targetDistance: Double?
    public var targetRpe: Double?
    public var restSeconds: Int?

    public init(
        order: Int,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        weightUnit: String? = nil,
        targetDurationSeconds: Int? = nil,
        targetDistance: Double? = nil,
        targetRpe: Double? = nil,
        restSeconds: Int? = nil
    ) {
        self.order = order
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.weightUnit = weightUnit
        self.targetDurationSeconds = targetDurationSeconds
        self.targetDistance = targetDistance
        self.targetRpe = targetRpe
        self.restSeconds = restSeconds
    }
}

extension ProgramPack {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case formatVersion
        case packID = "packId"
        case generatedAt
        case exercises
        case routines
        case programs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) {
            self.schemaVersion = schemaVersion
        } else {
            self.schemaVersion = (try? container.decode(Int.self, forKey: .formatVersion)) ?? ProgramPack.supportedSchemaVersion
        }

        self.generatedAt = try? container.decode(Date.self, forKey: .generatedAt)
        self.exercises = (try? container.decode([ExerciseDTO].self, forKey: .exercises)) ?? []
        self.routines = (try? container.decode([RoutineDTO].self, forKey: .routines)) ?? []
        self.programs = (try? container.decode([TrainingProgram].self, forKey: .programs)) ?? []

        let decodedPackID = try? container.decode(String.self, forKey: .packID)
        self.packID = Self.normalizedPackID(decodedPackID, programs: programs)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .formatVersion)
        try container.encode(packID, forKey: .packID)
        try container.encodeIfPresent(generatedAt, forKey: .generatedAt)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(routines, forKey: .routines)
        try container.encode(programs, forKey: .programs)
    }
}
