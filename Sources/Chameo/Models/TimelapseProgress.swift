import Foundation

/// Counts describe appended frames; download fractions describe just one photo.
enum TimelapseProgress: Equatable, Sendable {
    case preparing
    case loadingPhoto(Int)
    case downloadingPhoto(Int, Double)
    case framesWritten(Int)
    case saving

    var phaseTitleKey: String {
        switch self {
        case .preparing: return "Preparing timelapse…"
        case .loadingPhoto: return "Loading photos…"
        case .downloadingPhoto: return "Downloading from iCloud…"
        case .framesWritten: return "Encoding video…"
        case .saving: return "Saving video…"
        }
    }

    var order: Int {
        switch self {
        case .preparing: return 0
        case .loadingPhoto(let index): return index * 4 + 1
        case .downloadingPhoto(let index, _): return index * 4 + 2
        case .framesWritten(let count): return count * 4
        case .saving: return .max
        }
    }

    var announcementKey: String {
        phaseTitleKey
    }

    func text(total: Int) -> String {
        switch self {
        case .preparing: return L10n.string("Preparing timelapse…")
        case .loadingPhoto(let index):
            return L10n.format("Loading photo %lld of %lld…", Int64(index + 1), Int64(total))
        case .downloadingPhoto(let index, let fraction):
            return L10n.format("Downloading photo %lld of %lld from iCloud · %lld%%",
                               Int64(index + 1), Int64(total), Int64((min(1, max(0, fraction)) * 100).rounded()))
        case .framesWritten(let count):
            return L10n.format("Photos completed: %lld of %lld", Int64(count), Int64(total))
        case .saving: return L10n.string("Saving video…")
        }
    }
}
