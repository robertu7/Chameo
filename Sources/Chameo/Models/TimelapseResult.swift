import Foundation

struct TimelapseResult: Codable, Equatable {
    let id: UUID
    let url: URL
    let bookmark: Data?
}

enum TimelapseResultError: LocalizedError {
    case unavailable
    var errorDescription: String? {
        L10n.string("This timelapse is no longer available. It may have been moved or deleted.")
    }
}
