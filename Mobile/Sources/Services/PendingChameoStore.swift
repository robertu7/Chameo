import ChameoCore
import Foundation

struct PendingChameo: Sendable {
    let data: Data
    let metadata: PendingChameoMetadata
}

actor PendingChameoStore {
    private let directory: URL
    private let fileManager: FileManager

    init(
        directory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directory = directory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("PendingChameo", isDirectory: true)
    }

    func load() throws -> PendingChameo? {
        let imageURL = directory.appendingPathComponent("pending.jpg")
        let metadataURL = directory.appendingPathComponent("pending.json")
        guard fileManager.fileExists(atPath: imageURL.path),
              fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        return PendingChameo(
            data: try Data(contentsOf: imageURL),
            metadata: try JSONDecoder().decode(
                PendingChameoMetadata.self,
                from: Data(contentsOf: metadataURL)
            )
        )
    }

    func save(_ pending: PendingChameo) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var protectedDirectory = directory
        try protectedDirectory.setResourceValues(resourceValues)

        try pending.data.write(
            to: directory.appendingPathComponent("pending.jpg"),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        try JSONEncoder().encode(pending.metadata).write(
            to: directory.appendingPathComponent("pending.json"),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    func discard() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }
}
