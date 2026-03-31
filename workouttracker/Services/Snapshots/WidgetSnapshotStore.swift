import Foundation
import OSLog

struct WidgetSnapshotStore {
    static let appGroupIdentifier = "group.garaged.org.workouttracker"
    static let snapshotFileName = "widget_snapshot.json"

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let baseDirectory: URL?
    private let logger: Logger

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        logger: Logger = Logger(
            subsystem: "org.garaged.workouttracker",
            category: "WidgetSnapshotStore"
        )
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        self.logger = logger

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func save(_ snapshot: WidgetExternalSnapshot) throws {
        guard let url = snapshotURL() else {
            logger.error("App Group container is unavailable for widget snapshot writes. Snapshot write skipped.")
            return
        }

        let data = try encoder.encode(snapshot)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: url, options: [.atomic])
    }

    func load() -> WidgetExternalSnapshot? {
        guard let url = snapshotURL() else {
            logger.debug("App Group container is unavailable for widget snapshot reads. Returning nil.")
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        do {
            return try decoder.decode(WidgetExternalSnapshot.self, from: data)
        } catch {
            logger.error("Failed to decode widget snapshot: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func snapshotURL() -> URL? {
        let rootDirectory: URL?

        if let baseDirectory {
            rootDirectory = baseDirectory
        } else {
            rootDirectory = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
            )
        }

        return rootDirectory?
            .appendingPathComponent("Widgets", isDirectory: true)
            .appendingPathComponent(Self.snapshotFileName)
    }
}
