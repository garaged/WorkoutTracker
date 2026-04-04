import Foundation

/// Local export state for Apple Health integration.
enum HealthKitExportState: String, Codable, CaseIterable, Sendable {
    case notRequested
    case notAvailable
    case pending
    case exported
    case failed
}
