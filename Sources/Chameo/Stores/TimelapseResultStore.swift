import Foundation

@MainActor
final class TimelapseResultStore {
    private static let key = "latestTimelapseResult"
    private let defaults: UserDefaults
    private var sessionResult: TimelapseResult?
    private(set) var latest: TimelapseResult?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        latest = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(TimelapseResult.self, from: $0) }
    }

    @discardableResult
    func save(id: UUID, url: URL) -> TimelapseResult {
        let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil
        )
        let result = TimelapseResult(id: id, url: url, bookmark: bookmark)
        sessionResult = result
        latest = result
        if let data = try? JSONEncoder().encode(result) { defaults.set(data, forKey: Self.key) }
        return result
    }

    /// Never open a path supplied by a notification; resolve our own saved record.
    func withURL(id: UUID, perform: (URL) throws -> Void) throws {
        guard let result = latest, result.id == id else { throw TimelapseResultError.unavailable }
        let url: URL
        var stale = false
        if let bookmark = result.bookmark {
            guard let resolved = try? URL(
                resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                relativeTo: nil, bookmarkDataIsStale: &stale
            ) else { throw TimelapseResultError.unavailable }
            url = resolved
        } else {
            guard sessionResult?.id == id else { throw TimelapseResultError.unavailable }
            url = result.url
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard FileManager.default.fileExists(atPath: url.path) else { throw TimelapseResultError.unavailable }
        if stale { save(id: id, url: url) }
        try perform(url)
    }
}
