import Foundation

enum TimelapseSelection {
    static func items<Item>(from items: [Item], options: TimelapseExportOptions,
                            calendar: Calendar, date: (Item) -> Date?) -> [Item] {
        let selected: [Item]
        if options.range == .allPhotos {
            selected = items
        } else if let interval = options.interval(calendar: calendar) {
            selected = items.filter { item in
                guard let date = date(item) else { return false }
                return date >= interval.start && date < interval.end
            }
        } else {
            selected = []
        }
        return allItemsChronologically(from: selected, date: date)
    }

    static func allItemsChronologically<Item>(
        from items: [Item],
        date: (Item) -> Date?
    ) -> [Item] {
        items.enumerated().map { index, item in
            (index: index, item: item, date: date(item))
        }
        .sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.index < rhs.index
            }
        }
        .map(\.item)
    }
}
