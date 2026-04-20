import Foundation

enum ProgramPackCodec {
    enum CodecError: LocalizedError, Equatable {
        case unsupportedSchemaVersion(Int)
        case decodeFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedSchemaVersion(let version):
                return "Unsupported program pack version: \(version)."
            case .decodeFailed:
                return "Failed to decode program pack."
            }
        }
    }

    private struct Header: Codable {
        var formatVersion: Int?
        var schemaVersion: Int?
    }

    private struct LegacyProgramPackV1: Codable {
        var formatVersion: Int
        var generatedAt: Date?
        var programs: [TrainingProgram]
    }

    static func decode(_ data: Data) throws -> ProgramPack {
        let decoder = makeDecoder()

        guard let header = try? decoder.decode(Header.self, from: data) else {
            throw CodecError.decodeFailed
        }

        let version = header.schemaVersion ?? header.formatVersion ?? 0
        switch version {
        case 1:
            guard let legacy = try? decoder.decode(LegacyProgramPackV1.self, from: data) else {
                throw CodecError.decodeFailed
            }
            return ProgramPack(
                schemaVersion: 1,
                packID: nil,
                generatedAt: legacy.generatedAt,
                exercises: [],
                routines: [],
                programs: legacy.programs
            )
        case ProgramPack.supportedSchemaVersion:
            guard let pack = try? decoder.decode(ProgramPack.self, from: data) else {
                throw CodecError.decodeFailed
            }
            return pack
        default:
            throw CodecError.unsupportedSchemaVersion(version)
        }
    }

    static func encode(_ pack: ProgramPack) throws -> Data {
        try makeEncoder().encode(pack)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
