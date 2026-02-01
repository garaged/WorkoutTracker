import Foundation

#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

/// Zips a directory into a single `.zip` file.
///
/// Why this exists:
/// - `FileManager.zipItem` is not available on all SDK/deployment-target combos.
/// - We keep zipping behind ONE abstraction so the exporter stays simple.
///
/// Implementation:
/// - Prefer ZIPFoundation (SPM) when available.
/// - If ZIPFoundation isn't added yet, we throw a clear error at runtime (but the project still compiles).
enum ZipArchiver {
    enum ZipError: LocalizedError {
        case zipFoundationMissing

        var errorDescription: String? {
            switch self {
            case .zipFoundationMissing:
                return "Full Backup (ZIP) requires ZIPFoundation. Add it via Swift Package Manager to enable zipping."
            }
        }
    }

    static func zipDirectory(at directoryURL: URL, to destinationZipURL: URL, keepParent: Bool = true) throws {
        #if canImport(ZIPFoundation)
        try FileManager.default.zipItem(
            at: directoryURL,
            to: destinationZipURL,
            shouldKeepParent: keepParent,
            compressionMethod: .deflate
        )
        #else
        throw ZipError.zipFoundationMissing
        #endif
    }
}
