import Foundation

enum ProgressDataAvailability: String, Codable, Hashable {
    case full
    case partial
    case insufficient
}
