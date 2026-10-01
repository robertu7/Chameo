import CryptoKit
import Foundation
import ImageIO
@preconcurrency import Photos
import UniformTypeIdentifiers

struct LocalPhotoSnapshot: Codable, Equatable, Sendable {
    let identifier: String
    let createdAt: Date?
    let modificationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let hasAdjustments: Bool

    init(identifier: String, createdAt: Date? = nil, modificationDate: Date?,
         pixelWidth: Int = 0, pixelHeight: Int = 0, hasAdjustments: Bool = false) {
        self.identifier = identifier
        self.createdAt = createdAt
        self.modificationDate = modificationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.hasAdjustments = hasAdjustments
    }

    init(asset: PHAsset) {
        let resources = PHAssetResource.assetResources(for: asset)
        self.init(identifier: asset.localIdentifier, createdAt: asset.creationDate,
                  modificationDate: asset.modificationDate, pixelWidth: asset.pixelWidth,
                  pixelHeight: asset.pixelHeight,
                  hasAdjustments: resources.contains { $0.type == .adjustmentData || $0.type == .fullSizePhoto })
    }

    func matchesCurrentOriginal(_ current: LocalPhotoSnapshot) -> Bool {
        modificationDate != nil && self == current && !hasAdjustments
    }
}

struct StoredLocalPhoto: Sendable {
    let data: Data
    let source: LocalPhotoSnapshot
    let representsCurrentOriginal: Bool

    func canRender(_ current: LocalPhotoSnapshot) -> Bool {
        representsCurrentOriginal && source.matchesCurrentOriginal(current)
    }
}

actor LocalPhotoStore {
    static let shared = LocalPhotoStore()

    private struct Record: Codable {
        let source: LocalPhotoSnapshot
        let folderID: UUID
        let filename: String
        let fileSize: Int
        let digest: String
        let representsCurrentOriginal: Bool
    }

    private struct Index: Codable {
        var version = 1
        var records: [String: Record] = [:]
    }

    private let indexURL: URL
    private let preferences: LocalPhotoPreferences
    private let folderAccess: any LocalPhotoFolderAccess
    private let fixedFolderURL: URL?
    private let trashItem: @Sendable (URL) throws -> Void
    private var configuration: LocalPhotoConfiguration
    private var index: Index?

    init(indexURL: URL = LocalPhotoStore.defaultIndexURL,
         preferences: LocalPhotoPreferences = LocalPhotoPreferences(),
         folderAccess: any LocalPhotoFolderAccess = SecurityScopedPhotoFolderAccess(),
         fixedFolderURL: URL? = LocalPhotoDestination.defaultURL,
         trashItem: @escaping @Sendable (URL) throws -> Void = {
             try FileManager.default.trashItem(at: $0, resultingItemURL: nil)
         }) {
        self.indexURL = indexURL
        self.preferences = preferences
        self.folderAccess = folderAccess
        self.fixedFolderURL = fixedFolderURL
        self.trashItem = trashItem
        var loaded = preferences.load()
        // Preserve legacy folder identities so the index can still read their
        // originals. Future writes always target the entitlement-backed folder.
        if let fixedFolderURL {
            let id = loaded.folders.first { $0.bookmark == nil }?.id ?? UUID()
            loaded.folders.removeAll { $0.id == id }
            loaded.folders.append(LocalPhotoFolder(id: id, bookmark: nil, displayPath: fixedFolderURL.path))
            loaded.activeFolderID = id
        } else {
            loaded.activeFolderID = nil
        }
        configuration = loaded
    }

    static var defaultIndexURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppDistribution.current.bundleIdentifier, isDirectory: true)
            .appendingPathComponent("LocalPhotos", isDirectory: true)
            .appendingPathComponent("index.json")
    }

    func settings() -> LocalPhotoConfiguration { configuration }

    func setEnabled(_ enabled: Bool) throws {
        if enabled { try prepareFixedFolder() }
        var next = configuration
        next.isEnabled = enabled
        try preferences.save(next)
        configuration = next
    }

    /// Create only on a save, export, enable, or explicit Open Folder action.
    /// A real write probe catches denied access before downloading old originals.
    private func prepareFixedFolder() throws {
        guard let url = fixedFolderURL, configuration.activeFolder != nil else {
            throw LocalPhotoError.folderUnavailable
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try validateDirectory(url)
        let probe = url.appendingPathComponent(".chameo-\(UUID().uuidString).probe")
        defer { try? FileManager.default.removeItem(at: probe) }
        try Data().write(to: probe, options: [.withoutOverwriting])
        // Persist the new folder identity before committing an index record.
        try preferences.save(configuration)
    }

    func activeFolderURL() throws -> URL {
        try prepareFixedFolder()
        guard let folder = configuration.activeFolder else { throw LocalPhotoError.folderUnavailable }
        return try withFolder(folder.id) { $0 }
    }

    func validateDestination() throws {
        guard configuration.isEnabled else {
            throw LocalPhotoError.folderUnavailable
        }
        try prepareFixedFolder()
    }

    func original(for source: LocalPhotoSnapshot) throws -> StoredLocalPhoto? {
        guard configuration.isEnabled else { return nil }
        try loadIndex()
        guard let record = index?.records[source.identifier] else { return nil }
        return try withFolder(record.folderID) { folder in
            let url = folder.appendingPathComponent(record.filename)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            guard data.count == record.fileSize, Self.digest(data) == record.digest else {
                throw LocalPhotoError.fileChanged
            }
            return StoredLocalPhoto(data: data, source: record.source,
                                    representsCurrentOriginal: record.representsCurrentOriginal)
        }
    }

    /// Retain records after removal so exports do not recreate user-deleted copies.
    func hasSavedOriginal(for identifier: String) throws -> Bool {
        try loadIndex()
        return index?.records[identifier] != nil
    }

    /// Explicit deletion works even when keeping new local copies is turned off.
    /// Only an intact indexed copy can be moved; changed user files stay in place.
    func trashOriginal(for identifier: String) throws {
        try loadIndex()
        guard let record = index?.records[identifier] else { return }
        try withFolder(record.folderID) { folder in
            let url = folder.appendingPathComponent(record.filename)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            guard data.count == record.fileSize, Self.digest(data) == record.digest else {
                throw LocalPhotoError.fileChanged
            }
            try trashItem(url)
        }
    }

    /// The synchronous actor operation serializes writes and deduplicates each asset.
    /// Neither changed user files nor preserved originals are ever overwritten.
    @discardableResult
    func saveOriginal(_ data: Data, source: LocalPhotoSnapshot,
                      fileExtension: String? = nil, representsCurrentOriginal: Bool = true,
                      restoreMissingCopy: Bool = false) throws -> Bool {
        guard configuration.isEnabled else { return false }
        try Task.checkCancellation()
        try loadIndex()
        if try original(for: source) != nil { return true }
        if !restoreMissingCopy, index?.records[source.identifier] != nil { return false }
        try prepareFixedFolder()
        guard let folder = configuration.activeFolder else { throw LocalPhotoError.folderUnavailable }
        let ext = try Self.imageExtension(data, suggested: fileExtension)
        return try withFolder(folder.id) { url in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let filename = "Chameo-\(formatter.string(from: source.createdAt ?? Date()))-\(UUID().uuidString).\(ext)"
            let destination = url.appendingPathComponent(filename)
            let staging = url.appendingPathComponent(".chameo-\(UUID().uuidString).partial")
            defer { try? FileManager.default.removeItem(at: staging) }
            try data.write(to: staging, options: [.withoutOverwriting])
            try Task.checkCancellation()
            // moveItem refuses to replace an existing file.
            try FileManager.default.moveItem(at: staging, to: destination)
            var next = index ?? Index()
            next.records[source.identifier] = Record(source: source, folderID: folder.id, filename: filename,
                                                     fileSize: data.count, digest: Self.digest(data),
                                                     representsCurrentOriginal: representsCurrentOriginal)
            // A completed user-owned photo survives even if index persistence fails.
            index = next
            try persist(next)
            return true
        }
    }

    private func withFolder<T>(_ id: UUID, perform: (URL) throws -> T) throws -> T {
        guard let position = configuration.folders.firstIndex(where: { $0.id == id }) else {
            throw LocalPhotoError.folderUnavailable
        }
        guard let bookmark = configuration.folders[position].bookmark else {
            guard id == configuration.activeFolderID, let url = fixedFolderURL else {
                throw LocalPhotoError.folderUnavailable
            }
            return try perform(url)
        }
        let resolved = try folderAccess.resolve(bookmark)
        let accessing = folderAccess.startAccessing(resolved.url)
        defer { if accessing { folderAccess.stopAccessing(resolved.url) } }
        try validateDirectory(resolved.url)
        if resolved.isStale || configuration.folders[position].displayPath != resolved.url.path {
            var next = configuration
            next.folders[position].bookmark = try folderAccess.bookmark(for: resolved.url)
            next.folders[position].displayPath = resolved.url.path
            try preferences.save(next)
            configuration = next
        }
        return try perform(resolved.url)
    }

    private func validateDirectory(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LocalPhotoError.folderUnavailable
        }
    }

    private func loadIndex() throws {
        guard index == nil else { return }
        guard FileManager.default.fileExists(atPath: indexURL.path) else { index = Index(); return }
        let loaded = try JSONDecoder().decode(Index.self, from: Data(contentsOf: indexURL))
        guard loaded.version == 1,
              loaded.records.values.allSatisfy({ !$0.filename.isEmpty && $0.filename == URL(fileURLWithPath: $0.filename).lastPathComponent
                  && $0.filename != "." && $0.filename != ".." }) else { throw LocalPhotoError.invalidIndex }
        index = loaded
    }

    private func persist(_ value: Index) throws {
        try FileManager.default.createDirectory(at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: indexURL, options: .atomic)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func imageExtension(_ data: Data, suggested: String?) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { throw LocalPhotoError.invalidImage }
        let ext = UTType(type as String)?.preferredFilenameExtension ?? suggested
        guard let ext, !ext.isEmpty, ext.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            throw LocalPhotoError.invalidImage
        }
        return ext.lowercased() == "jpeg" ? "jpg" : ext.lowercased()
    }
}
