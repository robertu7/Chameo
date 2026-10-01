import Foundation

struct LocalPhotoFolder: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    // Only destinations selected in older versions need security-scoped access.
    var bookmark: Data?
    var displayPath: String
}

struct LocalPhotoConfiguration: Codable, Equatable, Sendable {
    var isEnabled = true
    var activeFolderID: UUID?
    var folders: [LocalPhotoFolder] = []

    var activeFolder: LocalPhotoFolder? {
        folders.first { $0.id == activeFolderID }
    }
}

struct ResolvedLocalPhotoFolder: Sendable {
    let url: URL
    let isStale: Bool
}

protocol LocalPhotoFolderAccess: Sendable {
    func bookmark(for url: URL) throws -> Data
    func resolve(_ bookmark: Data) throws -> ResolvedLocalPhotoFolder
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

struct SecurityScopedPhotoFolderAccess: LocalPhotoFolderAccess {
    func bookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolve(_ bookmark: Data) throws -> ResolvedLocalPhotoFolder {
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        return ResolvedLocalPhotoFolder(url: url, isStale: stale)
    }

    func startAccessing(_ url: URL) -> Bool { url.startAccessingSecurityScopedResource() }
    func stopAccessing(_ url: URL) { url.stopAccessingSecurityScopedResource() }
}

/// UserDefaults supports concurrent access; the store actor serializes our updates.
final class LocalPhotoPreferences: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "localPhotoConfiguration"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> LocalPhotoConfiguration {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(LocalPhotoConfiguration.self, from: data) else {
            return LocalPhotoConfiguration()
        }
        return value
    }

    func save(_ value: LocalPhotoConfiguration) throws {
        defaults.set(try JSONEncoder().encode(value), forKey: key)
    }
}

enum LocalPhotoError: LocalizedError, Equatable {
    case folderUnavailable, fileChanged, invalidIndex, invalidImage

    var errorDescription: String? {
        switch self {
        case .folderUnavailable:
            return L10n.string("The photo folder is unavailable. Check that your Pictures folder is writable and has enough free space.")
        case .fileChanged:
            return L10n.string("A local photo has changed. Chameo will use the version in Photos.")
        case .invalidIndex:
            return L10n.string("Could not read the local photo index. Chameo will use Photos.")
        case .invalidImage:
            return L10n.string("Could not read the original photo.")
        }
    }
}
