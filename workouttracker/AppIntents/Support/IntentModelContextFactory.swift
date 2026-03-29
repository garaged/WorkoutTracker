import Foundation
import SwiftData

enum IntentModelContextFactory {
    static func makeContext() throws -> ModelContext {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)

        let storeURL = appSupport.appendingPathComponent("default.store")
        let container = try ModelContainerFactory.makeOnDiskContainer(name: "default", storeURL: storeURL)
        return ModelContext(container)
    }
}
