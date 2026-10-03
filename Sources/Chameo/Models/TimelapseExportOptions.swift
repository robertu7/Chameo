import Foundation

enum TimelapseDateRange: String, CaseIterable, Identifiable {
    case allPhotos, month, year
    var id: String { rawValue }

    var title: String {
        switch self {
        case .allPhotos: return L10n.string("All Photos")
        case .month: return L10n.string("Month")
        case .year: return L10n.string("Year")
        }
    }
}

enum TimelapsePlaybackSpeed: Int32, CaseIterable, Identifiable {
    case slow = 5, standard = 10, fast = 15
    var id: Int32 { rawValue }
}

struct TimelapseExportOptions: Equatable {
    var range: TimelapseDateRange = .allPhotos
    var speed: TimelapsePlaybackSpeed = .standard
    var period: Date

    init(date: Date = Date()) {
        period = date
    }

    /// Calendar periods exclude undated photos and use local month/year boundaries.
    func interval(calendar: Calendar) -> DateInterval? {
        switch range {
        case .allPhotos: return nil
        case .month: return calendar.dateInterval(of: .month, for: period)
        case .year: return calendar.dateInterval(of: .year, for: period)
        }
    }
}
