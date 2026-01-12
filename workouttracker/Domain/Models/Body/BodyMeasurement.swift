import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    @Attribute(.unique) var id: UUID

    var measuredAt: Date
    var typeRaw: String
    var value: Double
    var unitRaw: String
    var note: String?

    init(
        id: UUID = UUID(),
        measuredAt: Date = Date(),
        type: BodyMeasurementType,
        value: Double,
        unit: BodyMeasurementUnit,
        note: String? = nil
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.typeRaw = type.rawValue
        self.value = value
        self.unitRaw = unit.rawValue
        self.note = note
    }

    var type: BodyMeasurementType {
        get { BodyMeasurementType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var unit: BodyMeasurementUnit {
        get { BodyMeasurementUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }
}
