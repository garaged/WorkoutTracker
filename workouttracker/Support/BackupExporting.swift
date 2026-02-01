import SwiftUI

/// Contract used by screens that want to export a shareable backup bundle.
///
/// Why this file exists:
/// - Keeps the protocol and the Environment key in one place, so you don't duplicate it in screens.
/// - Makes testing easy (inject a fake exporter).
protocol BackupExporting {
    func exportBackup() throws -> URL
}

private struct BackupExporterKey: EnvironmentKey {
    static let defaultValue: (any BackupExporting)? = nil
}

extension EnvironmentValues {
    var backupExporter: (any BackupExporting)? {
        get { self[BackupExporterKey.self] }
        set { self[BackupExporterKey.self] = newValue }
    }
}
