import Foundation

struct WidgetSnapshotStore {
    static let appGroupIdentifier = "group.garaged.org.workouttracker"
    static let snapshotFileName = "widget_snapshot.json"

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ snapshot: WidgetExternalSnapshot) throws {
        guard let url = snapshotURL() else {
            assertionFailure("App Group container is unavailable for widget snapshot writes")
            return
        }

        let data = try encoder.encode(snapshot)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func load() -> WidgetExternalSnapshot? {
        guard let url = snapshotURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? decoder.decode(WidgetExternalSnapshot.self, from: data)
    }

    func snapshotURL() -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)?
            .appendingPathComponent("Widgets", isDirectory: true)
            .appendingPathComponent(Self.snapshotFileName)
    }
}
